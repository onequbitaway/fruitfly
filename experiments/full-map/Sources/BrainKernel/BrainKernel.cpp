#include "BrainKernel.h"
#include <array>
#include <vector>
#include <string>
#include <cmath>
#include <cstring>
#include <stdexcept>
#include <algorithm>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>

// Native implementation of the LIF equations and parameters in Shiu et al. 2024.
// Adaptation to MaleCNS, input selection, and biological transfer remain unvalidated.
// u is voltage above -52 mV. g is the synaptic drive, measured in mV.
// 0.2 ms steps preserve the published 1.8 ms delay and 2.2 ms refractory period.
struct FFBrain {
    void *mapping = MAP_FAILED;
    size_t bytes = 0;
    uint32_t n = 0, m = 0;
    uint64_t contacts = 0, tick = 0, random = 7, spikes = 0, processed = 0;
    const uint32_t *offsets = nullptr, *targets = nullptr, *counts = nullptr;
    const float *signs = nullptr;
    std::vector<float> u, g, rates;
    std::vector<int32_t> arrivals;
    std::vector<uint64_t> refractory;
    std::vector<uint32_t> active, frameCounts;
    std::vector<uint8_t> awake, silenced, forced;
    std::array<std::vector<uint32_t>, 10> delay;
    const float membraneDecay = std::exp(-0.2f / 20.f);
    const float synapseDecay = std::exp(-0.2f / 5.f);
    const float coupling = (membraneDecay - synapseDecay) / 3.f;
    ~FFBrain() { if (mapping != MAP_FAILED) munmap(mapping, bytes); }
    void wake(uint32_t i) {
        if (!awake[i]) { awake[i] = 1; active.push_back(i); }
    }
    float unit(uint32_t cell) {
        uint32_t x = cell ^ uint32_t(tick) * 747796405U ^ uint32_t(random) * 2891336453U;
        x ^= x >> 16; x *= 2246822519U; x ^= x >> 13; x *= 3266489917U; x ^= x >> 16;
        return float(x >> 8) / 16777216.f;
    }
    void spike(uint32_t i, bool input) {
        ++frameCounts[i]; ++spikes;
        u[i] = 0; g[i] = 0;
        refractory[i] = tick + (input ? 0 : 11);
        delay[(tick + 9) % 10].push_back(i);
    }
};
static thread_local std::string lastError;
extern "C" {
float FFMembraneDecay(void) { return std::exp(-0.2f / 20.f); }
float FFSynapseDecay(void) { return std::exp(-0.2f / 5.f); }
float FFCoupling(void) { return (FFMembraneDecay() - FFSynapseDecay()) / 3.f; }
const char *FFLastError(void) { return lastError.c_str(); }
FFBrain *FFCreate(const char *path) {
    FFBrain *b = new FFBrain();
    try {
        int fd = open(path, O_RDONLY);
        if (fd < 0) throw std::runtime_error("Cannot open network data");
        struct stat status;
        if (fstat(fd, &status) != 0) { close(fd); throw std::runtime_error("Cannot read network size"); }
        b->bytes = status.st_size;
        b->mapping = mmap(nullptr, b->bytes, PROT_READ, MAP_PRIVATE, fd, 0);
        close(fd);
        if (b->mapping == MAP_FAILED || b->bytes < 24) throw std::runtime_error("Cannot map network data");
        const uint8_t *p = static_cast<const uint8_t *>(b->mapping);
        if (memcmp(p, "FFBRN001", 8) != 0) throw std::runtime_error("Wrong network format");
        memcpy(&b->n, p+8, 4); memcpy(&b->m, p+12, 4); memcpy(&b->contacts, p+16, 8);
        const uint64_t expected = 24ULL + (uint64_t(b->n)+1)*4 + uint64_t(b->m)*8 + uint64_t(b->n)*4;
        if (!b->n || expected != b->bytes) throw std::runtime_error("Incomplete network file");
        b->offsets = reinterpret_cast<const uint32_t *>(p+24);
        b->targets = b->offsets + b->n + 1;
        b->counts = b->targets + b->m;
        b->signs = reinterpret_cast<const float *>(b->counts + b->m);
        if (b->offsets[0] != 0 || b->offsets[b->n] != b->m) throw std::runtime_error("Invalid connection offsets");
        for (uint32_t i=0;i<b->n;++i) {
            if (b->offsets[i] > b->offsets[i+1] || (b->signs[i]!=1 && b->signs[i]!=-1)) throw std::runtime_error("Invalid cell data");
        }
        uint64_t sum = 0;
        std::vector<uint64_t> incoming(b->n, 0);
        for (uint32_t e=0;e<b->m;++e) {
            if (b->targets[e]>=b->n || !b->counts[e]) throw std::runtime_error("Invalid connection");
            sum += b->counts[e];
            incoming[b->targets[e]] += b->counts[e];
        }
        if (*std::max_element(incoming.begin(), incoming.end()) > 2147483647ULL) throw std::runtime_error("Incoming contacts exceed accumulator range");
        if (sum != b->contacts) throw std::runtime_error("Contact count does not match");
        b->u.resize(b->n); b->g.resize(b->n); b->rates.resize(b->n); b->arrivals.resize(b->n);
        b->refractory.resize(b->n); b->frameCounts.resize(b->n);
        b->awake.resize(b->n); b->silenced.resize(b->n); b->forced.resize(b->n);
        b->active.reserve(b->n);
        return b;
    } catch (const std::exception &e) { lastError = e.what(); delete b; return nullptr; }
}
void FFDestroy(FFBrain *b) { delete b; }
void FFReset(FFBrain *b, uint64_t seed) {
    for (auto *v : {&b->u, &b->g, &b->rates}) std::fill(v->begin(), v->end(), 0.f);
    std::fill(b->arrivals.begin(), b->arrivals.end(), 0);
    std::fill(b->refractory.begin(), b->refractory.end(), 0);
    std::fill(b->frameCounts.begin(), b->frameCounts.end(), 0);
    std::fill(b->awake.begin(), b->awake.end(), 0);
    std::fill(b->forced.begin(), b->forced.end(), 0);
    b->active.clear(); for (auto &events : b->delay) events.clear();
    b->tick = 0; b->random = seed ? seed : 7; b->spikes = 0; b->processed = 0;
}
uint32_t FFCellCount(const FFBrain *b) { return b->n; }
uint32_t FFConnectionCount(const FFBrain *b) { return b->m; }
uint64_t FFContactCount(const FFBrain *b) { return b->contacts; }
double FFTime(const FFBrain *b) { return double(b->tick) * .0002; }
const float *FFRates(const FFBrain *b) { return b->rates.data(); }
const float *FFVoltages(const FFBrain *b) { return b->u.data(); }
uint64_t FFTotalSpikes(const FFBrain *b) { return b->spikes; }
uint64_t FFProcessedContacts(const FFBrain *b) { return b->processed; }
void FFSilence(FFBrain *b, uint32_t cell, int enabled) { if (cell < b->n) b->silenced[cell] = enabled != 0; }
void FFAdvance(FFBrain *b, const uint32_t *cells, const float *hz, uint32_t count) {
    std::fill(b->frameCounts.begin(), b->frameCounts.end(), 0);
    // Active cells contain all nonzero dynamic states. Unvisited cells stay at rest.
    // This avoids updating untouched zeros; no network cell or edge is removed.
    for (int step=0;step<500;++step) {
        auto &due = b->delay[b->tick % 10];
        for (uint32_t source : due) {
            if (b->silenced[source]) continue;
            const int32_t direction = int32_t(b->signs[source]);
            for (uint32_t e=b->offsets[source];e<b->offsets[source+1];++e) {
                uint32_t target = b->targets[e];
                ++b->processed;
                if (b->silenced[target] || b->tick < b->refractory[target]) continue;
                b->arrivals[target] += direction * int32_t(b->counts[e]);
                b->wake(target);
            }
        }
        due.clear();
        for (uint32_t k=0;k<count;++k) {
            uint32_t cell = cells[k];
            if (cell >= b->n || b->silenced[cell] || !std::isfinite(hz[k]) || hz[k] <= 0) continue;
            if (b->unit(cell) < std::min(1.f, hz[k] * .0002f)) {
                b->spike(cell, true); b->forced[cell] = 1;
            }
        }
        size_t kept = 0;
        for (uint32_t i : b->active) {
            if (!b->silenced[i] && !b->forced[i] && b->tick >= b->refractory[i]) {
                b->g[i] += float(b->arrivals[i]) * .275f;
                b->u[i] = b->u[i] * b->membraneDecay + b->g[i] * b->coupling;
                b->g[i] *= b->synapseDecay;
                if (b->u[i] > 7.f) b->spike(i, false);
            }
            b->arrivals[i] = 0;
            if (b->silenced[i] || (std::abs(b->u[i]) < 1.e-6f && std::abs(b->g[i]) < 1.e-6f)) {
                b->u[i] = 0; b->g[i] = 0; b->awake[i] = 0;
            } else { b->active[kept++] = i; }
        }
        b->active.resize(kept);
        for (uint32_t k=0;k<count;++k) if (cells[k] < b->n) b->forced[cells[k]] = 0;
        ++b->tick;
    }
    for (uint32_t i=0;i<b->n;++i) b->rates[i] = float(b->frameCounts[i]) * 10.f;
}
}
