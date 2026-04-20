// SL3DVTKCompat.h — Horos VTK 8 runtime compatibility helpers
//
// Horos embeds VTK 8.x while this plugin is compiled with VTK 9.x headers.
// This header centralizes the low-level helpers that are safe under that ABI
// mismatch: struct-offset reads, explicit base dispatch, matrix extraction, and
// manual tube mesh generation.

#pragma once

#import <Foundation/Foundation.h>
#import "Constants.h"

#ifdef __cplusplus
#define id Id
#include "vtkActor.h"
#include "vtkCellArray.h"
#include "vtkDataArray.h"
#include "vtkIdTypeArray.h"
#include "vtkMapper.h"
#include "vtkPoints.h"
#include "vtkPolyData.h"
#include <cmath>
#include <limits>
#include <vector>
#undef id

typedef struct { double m[4][4]; } SL3DMatrix44;

// Verified on Horos's embedded VTK 8 runtime.
static constexpr ptrdiff_t kSL3DVTK8Matrix4x4ElementOffset = 48;

// Safe delete for VTK objects: bypasses virtual UnRegister vtable dispatch.
static inline void SL3DDelete(vtkObjectBase *obj) {
    if (obj) obj->vtkObjectBase::UnRegister(nullptr);
}

static inline vtkMapper *SL3DGetMapper(vtkActor *actor) {
    if (!actor) return nullptr;
    return *reinterpret_cast<vtkMapper **>(
        reinterpret_cast<uint8_t *>(actor) + 0x178);
}

// Read vtkCellArray::NumberOfCells at VTK-8 offset 0x30.
static inline vtkIdType SL3DReadCellArrayCount(void *ca) {
    if (!ca) return 0;
    return *reinterpret_cast<vtkIdType *>(reinterpret_cast<uint8_t *>(ca) + 0x30);
}

static inline vtkIdType SL3DGetPolyDataPolygonCount(vtkPolyData *pd) {
    if (!pd) return 0;
    void *polys = *reinterpret_cast<void **>(reinterpret_cast<uint8_t *>(pd) + 0x150);
    vtkIdType nPolys = SL3DReadCellArrayCount(polys);
    if (nPolys > 0) return nPolys;
    void *strips = *reinterpret_cast<void **>(reinterpret_cast<uint8_t *>(pd) + 0x158);
    return SL3DReadCellArrayCount(strips);
}

static inline vtkIdType SL3DFindClosestInBuffer(const float *verts, vtkIdType numPts, const double q[3]) {
    vtkIdType bestId = 0;
    double bestDist2 = std::numeric_limits<double>::max();
    float qx = (float)q[0], qy = (float)q[1], qz = (float)q[2];
    for (vtkIdType i = 0; i < numPts; i++) {
        float dx = verts[i*3]-qx, dy = verts[i*3+1]-qy, dz = verts[i*3+2]-qz;
        double d2 = (double)dx*dx + (double)dy*dy + (double)dz*dz;
        if (d2 < bestDist2) { bestDist2 = d2; bestId = i; }
    }
    return bestId;
}

static inline void SL3DGetPoint(vtkPolyData *pd, vtkIdType id, double *out) {
    vtkPoints *pts = *reinterpret_cast<vtkPoints **>(
        reinterpret_cast<uint8_t *>(pd) + 0xe8);
    if (!pts) { out[0] = out[1] = out[2] = 0.0; return; }
    vtkDataArray *da = *reinterpret_cast<vtkDataArray **>(
        reinterpret_cast<uint8_t *>(pts) + 0x68);
    if (!da) { out[0] = out[1] = out[2] = 0.0; return; }
    void *buf = *reinterpret_cast<void **>(reinterpret_cast<uint8_t *>(da) + 0xe0);
    if (!buf) { out[0] = out[1] = out[2] = 0.0; return; }
    float *data = *reinterpret_cast<float **>(reinterpret_cast<uint8_t *>(buf) + 0x30);
    if (!data) { out[0] = out[1] = out[2] = 0.0; return; }
    out[0] = data[id * 3];
    out[1] = data[id * 3 + 1];
    out[2] = data[id * 3 + 2];
}

static inline void SL3DInvertMatrix44(const double m[4][4], double inv[4][4]) {
    double a[4][8];
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) a[i][j] = m[i][j];
        for (int j = 0; j < 4; j++) a[i][4+j] = (i == j) ? 1.0 : 0.0;
    }
    for (int col = 0; col < 4; col++) {
        int pivot = col;
        for (int row = col+1; row < 4; row++)
            if (std::fabs(a[row][col]) > std::fabs(a[pivot][col])) pivot = row;
        if (pivot != col)
            for (int j = 0; j < 8; j++) std::swap(a[col][j], a[pivot][j]);
        double d = a[col][col];
        if (std::fabs(d) < 1e-12) {
            memset(inv, 0, 16 * sizeof(double));
            for (int i = 0; i < 4; i++) inv[i][i] = 1.0;
            return;
        }
        for (int j = 0; j < 8; j++) a[col][j] /= d;
        for (int row = 0; row < 4; row++) {
            if (row == col) continue;
            double f = a[row][col];
            for (int j = 0; j < 8; j++) a[row][j] -= f * a[col][j];
        }
    }
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++)
            inv[i][j] = a[i][4+j];
}

static inline void SL3DTransformPoint(const double M[4][4], const double in[3], double out[3]) {
    double w = M[3][0]*in[0] + M[3][1]*in[1] + M[3][2]*in[2] + M[3][3];
    if (std::fabs(w) < 1e-12) w = 1.0;
    out[0] = (M[0][0]*in[0] + M[0][1]*in[1] + M[0][2]*in[2] + M[0][3]) / w;
    out[1] = (M[1][0]*in[0] + M[1][1]*in[1] + M[1][2]*in[2] + M[1][3]) / w;
    out[2] = (M[2][0]*in[0] + M[2][1]*in[1] + M[2][2]*in[2] + M[2][3]) / w;
}

static inline bool SL3DReadVTKMatrix4x4(vtkMatrix4x4 *mat, SL3DMatrix44 &out) {
    if (!mat) return false;
    const double *elems = reinterpret_cast<const double *>(
        reinterpret_cast<const uint8_t *>(mat) + kSL3DVTK8Matrix4x4ElementOffset);
    for (int r = 0; r < 4; r++)
        for (int c = 0; c < 4; c++)
            out.m[r][c] = elems[r * 4 + c];
    return true;
}

static inline bool SL3DGetActorMatrix(vtkActor *actor, SL3DMatrix44 &out) {
    if (!actor) return false;
    vtkMatrix4x4 *mat = vtkMatrix4x4::New();
    if (!mat) return false;
    actor->vtkProp3D::GetMatrix(mat);
    bool ok = SL3DReadVTKMatrix4x4(mat, out);
    SL3DDelete(mat);
    return ok;
}

static inline double SL3DTubeRadiusForWidth(double width) {
    if (width < 1.0) width = 1.0;
    return width * 0.5;
}

static inline void SL3DVecSub(const double a[3], const double b[3], double out[3]) {
    out[0] = a[0] - b[0];
    out[1] = a[1] - b[1];
    out[2] = a[2] - b[2];
}

static inline double SL3DVecNorm(double v[3]) {
    double n = std::sqrt(v[0]*v[0] + v[1]*v[1] + v[2]*v[2]);
    if (n > 1e-12) {
        v[0] /= n; v[1] /= n; v[2] /= n;
    }
    return n;
}

static inline void SL3DVecCross(const double a[3], const double b[3], double out[3]) {
    out[0] = a[1]*b[2] - a[2]*b[1];
    out[1] = a[2]*b[0] - a[0]*b[2];
    out[2] = a[0]*b[1] - a[1]*b[0];
}

static inline vtkPolyData *SL3DBuildTubePolyData(NSArray<NSValue *> *pts, double radius) {
    const NSInteger ringSides = 12;
    const NSInteger pointCount = (NSInteger)pts.count;
    if (pointCount < 2) return nullptr;

    vtkPoints *tubePoints = vtkPoints::New();
    vtkDataArray *tubePointData = *reinterpret_cast<vtkDataArray **>(
        reinterpret_cast<uint8_t *>(tubePoints) + 0x68);
    if (!tubePointData) {
        SL3DDelete(tubePoints);
        return nullptr;
    }

    std::vector<vtkIdType> polyBuffer;
    polyBuffer.reserve((size_t)(pointCount - 1) * ringSides * 5);

    for (NSInteger i = 0; i < pointCount; i++) {
        SL3DPoint currPt, prevPt, nextPt;
        [pts[i] getValue:&currPt];
        [pts[(i > 0) ? (i - 1) : i] getValue:&prevPt];
        [pts[(i + 1 < pointCount) ? (i + 1) : i] getValue:&nextPt];

        double curr[3] = { currPt.x, currPt.y, currPt.z };
        double prev[3] = { prevPt.x, prevPt.y, prevPt.z };
        double next[3] = { nextPt.x, nextPt.y, nextPt.z };

        double tangent[3];
        if (i == 0) SL3DVecSub(next, curr, tangent);
        else if (i == pointCount - 1) SL3DVecSub(curr, prev, tangent);
        else {
            tangent[0] = next[0] - prev[0];
            tangent[1] = next[1] - prev[1];
            tangent[2] = next[2] - prev[2];
        }
        if (SL3DVecNorm(tangent) < 1e-12) {
            tangent[0] = 1.0; tangent[1] = 0.0; tangent[2] = 0.0;
        }

        double ref[3] = { 0.0, 0.0, 1.0 };
        if (std::fabs(tangent[2]) > 0.9) {
            ref[0] = 0.0; ref[1] = 1.0; ref[2] = 0.0;
        }

        double normal[3];
        SL3DVecCross(ref, tangent, normal);
        if (SL3DVecNorm(normal) < 1e-12) {
            ref[0] = 1.0; ref[1] = 0.0; ref[2] = 0.0;
            SL3DVecCross(ref, tangent, normal);
            SL3DVecNorm(normal);
        }

        double binormal[3];
        SL3DVecCross(tangent, normal, binormal);
        SL3DVecNorm(binormal);

        for (NSInteger s = 0; s < ringSides; s++) {
            double theta = (2.0 * M_PI * (double)s) / (double)ringSides;
            double cs = std::cos(theta), sn = std::sin(theta);
            double x = curr[0] + radius * (cs * normal[0] + sn * binormal[0]);
            double y = curr[1] + radius * (cs * normal[1] + sn * binormal[1]);
            double z = curr[2] + radius * (cs * normal[2] + sn * binormal[2]);
            tubePointData->vtkDataArray::InsertNextTuple3(x, y, z);
        }
    }

    for (NSInteger i = 0; i < pointCount - 1; i++) {
        vtkIdType base0 = (vtkIdType)(i * ringSides);
        vtkIdType base1 = (vtkIdType)((i + 1) * ringSides);
        for (NSInteger s = 0; s < ringSides; s++) {
            vtkIdType a = base0 + s;
            vtkIdType b = base0 + ((s + 1) % ringSides);
            vtkIdType c = base1 + ((s + 1) % ringSides);
            vtkIdType d = base1 + s;
            polyBuffer.push_back(4);
            polyBuffer.push_back(a);
            polyBuffer.push_back(b);
            polyBuffer.push_back(c);
            polyBuffer.push_back(d);
        }
    }

    vtkIdTypeArray *polyIds = vtkIdTypeArray::New();
    vtkDataArray *polyData = static_cast<vtkDataArray *>(polyIds);
    for (vtkIdType v : polyBuffer)
        polyData->vtkDataArray::InsertNextTuple1((double)v);

    vtkCellArray *polys = vtkCellArray::New();
    polys->vtkCellArray::SetCells((vtkIdType)((pointCount - 1) * ringSides), polyIds);
    SL3DDelete(polyIds);

    vtkPolyData *tubeData = vtkPolyData::New();
    static_cast<vtkPointSet *>(tubeData)->vtkPointSet::SetPoints(tubePoints);
    tubeData->vtkPolyData::SetPolys(polys);

    SL3DDelete(tubePoints);
    SL3DDelete(polys);
    return tubeData;
}

#endif
