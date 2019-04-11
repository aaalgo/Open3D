// ----------------------------------------------------------------------------
// -                        Open3D: www.open3d.org                            -
// ----------------------------------------------------------------------------
// The MIT License (MIT)
//
// Copyright (c) 2018 www.open3d.org
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
// ----------------------------------------------------------------------------

#include <stdio.h>

#include "Open3D/Utility/CUDA.cuh"
#include "Open3D/Types/Mat.h"
using namespace open3d;

#include <iostream>
#include <vector>
#include <tuple>
using namespace std;

// ---------------------------------------------------------------------------
// accumulate device function
// ---------------------------------------------------------------------------
__device__ void accumulate(Mat3d* c, Vec3d p) {
    (*c)[0][0] += p[0];
    (*c)[0][1] += p[1];
    (*c)[0][2] += p[2];
    (*c)[1][0] += p[0] * p[0];
    (*c)[1][1] += p[0] * p[1];
    (*c)[1][2] += p[0] * p[2];
    (*c)[2][0] += p[1] * p[1];
    (*c)[2][1] += p[1] * p[2];
    (*c)[2][2] += p[2] * p[2];
}

// ---------------------------------------------------------------------------
// meanAndCovarianceAccumulator kernel
// ---------------------------------------------------------------------------
__global__ void meanAndCovarianceAccumulator(double* data,
                                             uint nr_points,
                                             double* output) {
    int gid = blockIdx.x * blockDim.x + threadIdx.x;

    Vec3d* points = (Vec3d*)data;
    Mat3d* cumulants = (Mat3d*)output;

    // initialize with zeros
    Mat3d c{};
    Vec3d p = points[gid];

    accumulate(&c, p);

    cumulants[gid] = c / nr_points;
}

// ---------------------------------------------------------------------------
// helper function calls the cumulant CUDA kernel
// ---------------------------------------------------------------------------
cudaError_t meanAndCovarianceAccumulatorHelper(const int& gpu_id,
                                               double* const d_points,
                                               const uint& nr_points,
                                               double* const d_cumulants) {
    int threadsPerBlock = 256;
    int blocksPerGrid = (nr_points + threadsPerBlock - 1) / threadsPerBlock;

    cudaSetDevice(gpu_id);
    meanAndCovarianceAccumulator<<<blocksPerGrid, threadsPerBlock>>>(
            d_points, nr_points, d_cumulants);
    cudaDeviceSynchronize();

    return cudaGetLastError();
}
