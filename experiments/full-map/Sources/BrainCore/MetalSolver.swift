import BrainKernel
import Foundation
import Metal

/// Runs the same 0.2 ms LIF steps on the GPU. No cell or edge sampling.
final class MetalSolver {
    let device: MTLDevice
    let cells: Int
    let graph: MTLBuffer
    let queue: MTLCommandQueue
    let prepare: MTLComputePipelineState
    let transmit: MTLComputePipelineState
    let integrate: MTLComputePipelineState
    let voltage: MTLBuffer
    let drive: MTLBuffer
    let synapticDrive: MTLBuffer
    let refractory: MTLBuffer
    let delayed: MTLBuffer
    let delayedCounts: MTLBuffer
    let indirect: MTLBuffer
    let frameCounts: MTLBuffer
    let stimulus: MTLBuffer
    let silenceFlags: MTLBuffer
    private(set) var tick: UInt32 = 0
    private(set) var totalSpikes: UInt64 = 0
    private var seed: UInt32 = 7
    private(set) var rates: [Float]
    private struct Parameters {
        var n: UInt32, m: UInt32, tick: UInt32, seed: UInt32
        var membrane: Float, synapse: Float, coupling: Float, weight: Float
    }
    let edges: Int
    init?(path: URL, cells: Int, edges: Int) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.queue = queue
        self.cells = cells
        self.edges = edges
        let data = try Data(contentsOf: path, options: .mappedIfSafe)
        guard
            let graph = data.withUnsafeBytes({
                device.makeBuffer(bytes: $0.baseAddress!, length: data.count, options: .storageModeShared)
            })
        else {
            throw Self.error("Cannot load the graph into graphics memory.")
        }
        self.graph = graph
        func buffer(_ length: Int) throws -> MTLBuffer {
            guard let result = device.makeBuffer(length: length, options: .storageModeShared) else {
                throw Self.error("Not enough graphics memory.")
            }
            memset(result.contents(), 0, length)
            return result
        }
        voltage = try buffer(cells * 4)
        drive = try buffer(cells * 4)
        synapticDrive = try buffer(cells * 4)
        refractory = try buffer(cells * 4)
        delayed = try buffer(cells * 10 * 4)
        delayedCounts = try buffer(10 * 4)
        indirect = try buffer(12)
        frameCounts = try buffer(cells * 4)
        stimulus = try buffer(cells * 4)
        silenceFlags = try buffer(cells * 4)
        rates = Array(repeating: 0, count: cells)
        let options = MTLCompileOptions()
        options.fastMathEnabled = false
        let library = try device.makeLibrary(source: Self.shader, options: options)
        prepare = try device.makeComputePipelineState(function: library.makeFunction(name: "prepare")!)
        transmit = try device.makeComputePipelineState(function: library.makeFunction(name: "transmit")!)
        integrate = try device.makeComputePipelineState(function: library.makeFunction(name: "integrate")!)
    }
    func reset(seed: UInt64) {
        for b in [voltage, drive, synapticDrive, refractory, delayed, delayedCounts, indirect, frameCounts, stimulus] {
            memset(b.contents(), 0, b.length)
        }
        rates = Array(repeating: 0, count: cells)
        tick = 0
        totalSpikes = 0
        self.seed = UInt32(truncatingIfNeeded: seed == 0 ? 7 : seed)
    }
    func silence(_ ids: [Int], enabled: Bool) {
        let flags = silenceFlags.contents().bindMemory(to: UInt32.self, capacity: cells)
        for i in ids where i >= 0 && i < cells { flags[i] = enabled ? 1 : 0 }
    }
    func voltageAboveRest(at index: Int) -> Float {
        voltage.contents().bindMemory(to: Float.self, capacity: cells)[index]
    }
    func advance(ids: [UInt32], frequencies: [Float]) throws {
        memset(frameCounts.contents(), 0, frameCounts.length)
        memset(stimulus.contents(), 0, stimulus.length)
        let inputs = stimulus.contents().bindMemory(to: Float.self, capacity: cells)
        for k in ids.indices { inputs[Int(ids[k])] = frequencies[k] }
        guard let command = queue.makeCommandBuffer(), let encoder = command.makeComputeCommandEncoder() else {
            throw Self.error("Cannot start a graphics calculation.")
        }
        for (index, buffer) in [graph, voltage, drive, refractory, delayed, frameCounts, stimulus, silenceFlags]
            .enumerated()
        {
            encoder.setBuffer(buffer, offset: 0, index: index)
        }
        encoder.setBuffer(synapticDrive, offset: 0, index: 9)
        encoder.setBuffer(delayedCounts, offset: 0, index: 10)
        encoder.setBuffer(indirect, offset: 0, index: 11)
        let membrane = FFMembraneDecay()
        let synapse = FFSynapseDecay()
        for _ in 0..<500 {
            var p = Parameters(
                n: UInt32(cells), m: UInt32(edges), tick: tick, seed: seed,
                membrane: membrane, synapse: synapse, coupling: FFCoupling(), weight: 0.275)
            encoder.setBytes(&p, length: MemoryLayout<Parameters>.stride, index: 8)
            encoder.setComputePipelineState(prepare)
            encoder.dispatchThreads(
                MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
            encoder.memoryBarrier(scope: .buffers)
            encoder.setComputePipelineState(transmit)
            encoder.dispatchThreadgroups(
                indirectBuffer: indirect, indirectBufferOffset: 0,
                threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1))
            encoder.memoryBarrier(scope: .buffers)
            encoder.setComputePipelineState(integrate)
            encoder.dispatchThreads(
                MTLSize(width: cells, height: 1, depth: 1),
                threadsPerThreadgroup: MTLSize(width: 128, height: 1, depth: 1))
            encoder.memoryBarrier(scope: .buffers)
            tick &+= 1
        }
        encoder.endEncoding()
        command.commit()
        command.waitUntilCompleted()
        if command.status == .error { throw command.error ?? Self.error("The graphics calculation failed.") }
        let counts = frameCounts.contents().bindMemory(to: UInt32.self, capacity: cells)
        for i in 0..<cells {
            rates[i] = Float(counts[i]) * 10
            totalSpikes += UInt64(counts[i])
        }
    }
    private static func error(_ message: String) -> NSError {
        NSError(domain: "FruitflyMetal", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
    private static let shader = """
        #include <metal_stdlib>
        using namespace metal;
        #pragma clang fp contract(off)
        struct Parameters { uint n,m,tick,seed; float membrane,synapse,coupling,weight; };
        kernel void prepare(device atomic_uint *sizes [[buffer(10)]], device uint *arguments [[buffer(11)]], constant Parameters &p [[buffer(8)]]) {
            atomic_store_explicit(&sizes[p.tick%10],0,memory_order_relaxed);
            arguments[0]=max(1u,atomic_load_explicit(&sizes[(p.tick+1)%10],memory_order_relaxed));
            arguments[1]=1; arguments[2]=1;
        }
        kernel void transmit(device const uint *graph [[buffer(0)]], device float *u [[buffer(1)]],
            device atomic_int *arrivals [[buffer(2)]], device const uint *refractory [[buffer(3)]],
            device uint *delay [[buffer(4)]], device uint *counts [[buffer(5)]],
            device const float *stimulus [[buffer(6)]], device const uint *silenced [[buffer(7)]],
            constant Parameters &p [[buffer(8)]], device float *g [[buffer(9)]], device atomic_uint *sizes [[buffer(10)]],
            uint group [[threadgroup_position_in_grid]], uint lane [[thread_index_in_threadgroup]]) {
            uint due=(p.tick+1)%10;
            if (group>=atomic_load_explicit(&sizes[due],memory_order_relaxed)) return;
            uint source=delay[due*p.n+group];
            if (silenced[source]) return;
            uint targetBase=p.n+7, countBase=targetBase+p.m;
            int direction=int(as_type<float>(graph[countBase+p.m+source]));
            for (uint e=graph[6+source]+lane;e<graph[7+source];e+=64) {
                uint target=graph[targetBase+e];
                if (!silenced[target] && p.tick>=refractory[target]) atomic_fetch_add_explicit(&arrivals[target],direction*int(graph[countBase+e]),memory_order_relaxed);
            }
        }
        kernel void integrate(device const uint *graph [[buffer(0)]], device float *u [[buffer(1)]],
            device atomic_int *arrivals [[buffer(2)]], device uint *refractory [[buffer(3)]],
            device uint *delay [[buffer(4)]], device uint *counts [[buffer(5)]],
            device const float *stimulus [[buffer(6)]], device const uint *silenced [[buffer(7)]],
            constant Parameters &p [[buffer(8)]], device float *g [[buffer(9)]], device atomic_uint *sizes [[buffer(10)]], uint i [[thread_position_in_grid]]) {
            if (i>=p.n) return;
            bool spike=false;
            float v=u[i], current=g[i];
            int incoming=atomic_load_explicit(&arrivals[i],memory_order_relaxed);
            atomic_store_explicit(&arrivals[i],0,memory_order_relaxed);
            bool forced=false;
            if (stimulus[i]>0) {
                uint x=i ^ p.tick*747796405u ^ p.seed*2891336453u;
                x^=x>>16; x*=2246822519u; x^=x>>13; x*=3266489917u; x^=x>>16;
                forced=float(x>>8)/16777216.0f < min(1.0f,stimulus[i]*.0002f);
            }
            if (silenced[i]) { v=0; current=0; }
            else if (forced) { spike=true; counts[i]+=1; v=0; current=0; refractory[i]=p.tick; }
            else if (p.tick>=refractory[i]) {
                // Preserve the CPU's two separately rounded operations even
                // on graphics drivers that contract multiply-add expressions.
                volatile float incomingDrive=float(incoming)*p.weight;
                current+=incomingDrive;
                volatile float decayedVoltage=v*p.membrane;
                volatile float coupledDrive=current*p.coupling;
                v=decayedVoltage+coupledDrive;
                current*=p.synapse;
                if (v>7.0f) { spike=true; counts[i]+=1; v=0; current=0; refractory[i]=p.tick+11; }
            }
            if (abs(v)<1.e-6f && abs(current)<1.e-6f) { v=0; current=0; }
            if (spike) {
                uint slot=atomic_fetch_add_explicit(&sizes[p.tick%10],1,memory_order_relaxed);
                delay[(p.tick%10)*p.n+slot]=i;
            }
            u[i]=v; g[i]=current;
        }
        """
}
