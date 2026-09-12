#ifndef FRUITFLY_BRAIN_KERNEL_H
#define FRUITFLY_BRAIN_KERNEL_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct FFBrain FFBrain;
FFBrain *FFCreate(const char *path);
const char *FFLastError(void);
void FFDestroy(FFBrain *brain);
void FFReset(FFBrain *brain, uint64_t seed);
uint32_t FFCellCount(const FFBrain *brain);
uint32_t FFConnectionCount(const FFBrain *brain);
uint64_t FFContactCount(const FFBrain *brain);
double FFTime(const FFBrain *brain);
// Share the exact rounded coefficients with the graphics solver.
float FFMembraneDecay(void);
float FFSynapseDecay(void);
float FFCoupling(void);
// Advance one 100 ms sample. Stimulus rates are Poisson event rates in Hz.
void FFAdvance(FFBrain *brain, const uint32_t *cells, const float *hz, uint32_t count);
const float *FFRates(const FFBrain *brain);
const float *FFVoltages(const FFBrain *brain);
uint64_t FFTotalSpikes(const FFBrain *brain);
uint64_t FFProcessedContacts(const FFBrain *brain);
void FFSilence(FFBrain *brain, uint32_t cell, int enabled);
#ifdef __cplusplus
}
#endif
#endif
