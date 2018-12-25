//
//  UIStrokeLib.h
//  IOSTouch
//
//  Created by Vitor Ciaramella on 12/20/18.
//  Copyright © 2018 Vitor Ciaramella. All rights reserved.
//

#ifndef UIStrokeLib_h
#define UIStrokeLib_h

#include <vector>

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#define UIStrokeFloat CGFloat
#define UIStrokeInt NSInteger
#define UIStrokeTime NSTimeInterval
#define UIStrokePoint CGPoint
#define UIStrokePointNull CGPointMake(NAN,NAN)
#define UIStrokePointMake CGPointMake

#define UIStrokePositionVectorInitialCapacity 1000
#define UIStrokePredictedPositionVectorInitialCapacity 100
#define UIStrokeActiveStrokesVectorInitialCapacity 20
#define UIStrokeStrokeArchiveVectorInitialCapacity 1000

struct UIStrokeSettings;
struct UIStrokeManager;
struct UIStrokePosition;
struct UIStrokePositionProperties;
using UIStrokeManagerShared = std::shared_ptr<UIStrokeManager>;
using UIStrokeManagerWeak = std::weak_ptr<UIStrokeManager>;
using UIStrokePositionVector = std::vector<UIStrokePosition>;
using UIStrokePositionVectorUnique = std::unique_ptr<UIStrokePositionVector>;
using UIStrokeSettingsShared = std::shared_ptr<UIStrokeSettings>;
using UIStrokePositionPropertiesVector = std::vector<UIStrokePositionProperties>;
using UIStrokePositionPropertiesUniqueVector = std::unique_ptr<UIStrokePositionPropertiesVector>;

typedef enum class UIStrokePositionSourceType {
    Actual,
    Coalesced,
    Predicted,
    Unknown,
} UIStrokePositionSourceType;

typedef enum class UIStrokeInputType {
    Direct,
    Pencil,
    Indirect,
    Unknown,
} UIStrokeInputType;

typedef enum class UIStrokePhase {
    Active,
    Completed,
    Cancelled,
    Unknown,
} UIStrokePhase;

typedef struct UIStrokeSettings {
    bool ArchiveNonActiveStrokes;
    bool KeepStrokePositionPropertyChangeLog;
    UIStrokeFloat MinimumStrokePositionDistance;
    bool CalculateSmoothBezierControlPoints;
    UIStrokeFloat CatmullRomAlpha;
    bool CollectDirectInput;
    bool CollectIndirectInput;
    bool CollectPencilInput;
    bool CollectForce;
    bool CollectAltitudeAngle;
    bool CollectAzimuthAngle;
    bool CollectLocation;
    bool CollectPreciseLocation;
    bool CollectCoalescedTouches;
    bool CollectPredictedTouches;
    bool CollectEstimatedProperties;
    bool UpdateEstimatedProperties;
    bool SimulateForceWithTouchRadius;
    bool CollectTouchRadius;
    UIStrokeFloat LocationSensitivity;
    UIStrokeFloat PreciseLocationSensitivity;
    UIStrokeFloat ForceSensitivity;
    UIStrokeFloat AltitudeAngleSensitivity;
    UIStrokeFloat AzimuthAngleSensitivity;
    UIStrokeFloat TouchRadiusSensitivity;
    UIStrokeFloat MinTouchRadiusForForceSimulation;
    UIStrokeFloat MaxTouchRadiusForForceSimulation;
    UIStrokeFloat DefaultNormalizedForce;
    
    UIStrokeSettings();
} UIStrokeSettings;

typedef struct UIStrokePositionProperties {
    UIStrokeTime Timestamp;
    UIStrokeFloat MajorRadius;
    UIStrokeFloat Force;
    UIStrokeFloat AltitudeAngle;
    UIStrokeFloat AzimuthAngle;
    UIStrokePositionProperties();
    UIStrokePositionProperties(UIStrokeTime timestamp, UIStrokeFloat majorRadius, UIStrokeFloat force, UIStrokeFloat altitudeAngle, UIStrokeFloat azimuthAngle);
    UIStrokeFloat NormalizedForce(UIStrokeFloat maxForce, UIStrokeFloat minRadius, UIStrokeFloat maxRadius, UIStrokeFloat defaultForce);
} UIStrokePositionProperties;

typedef struct UIStrokePosition {
    UIStrokeTime Timestamp;
    UIStrokePoint Position;
    UIStrokePoint SmoothControlPoint1;
    UIStrokePoint SmoothControlPoint2;
    UIStrokePositionSourceType SourceType;
    UIStrokePositionProperties Properties;
    UIStrokePositionPropertiesUniqueVector PropertiesChangeLog;
    UIStrokePosition();
    UIStrokePosition(UIStrokeTime timestamp, UIStrokePoint position, UIStrokePositionSourceType sourceType, UIStrokePositionProperties properties, bool keepPropertyChangeLog);
    UIStrokePosition(UIStrokeTime timestamp, UIStrokePoint position, UIStrokePositionSourceType sourceType);
    UIStrokePosition(UIStrokePosition&& strokePosition);
    UIStrokePosition(const UIStrokePosition& strokePosition);
    UIStrokePosition& operator=(UIStrokePosition&& strokePosition);
    UIStrokePosition& operator=(const UIStrokePosition& strokePosition);
    void SetProperties(UIStrokePositionProperties& properties, bool keepPropertyChangeLog);
    void Shrink();
    void CalculateSmoothControlPoints(UIStrokePoint nextPosition, UIStrokePoint previousPosition, UIStrokePoint previousPreviousPosition, UIStrokeFloat minControlPointDistance, UIStrokeFloat alpha);
} UIStrokePosition;

typedef struct UIStroke {
public:
    UIStrokeInt StrokeId;
    UIStrokeTime Timestamp;
    UIStrokeInputType InputType;
    UIStrokePhase StrokePhase;
    UIStrokeFloat TapCount;
    UIStrokeFloat MajorRadiusTolerance;
    UIStrokeFloat MaxPossibleForce;
    UIStrokePositionVectorUnique Positions;
    UIStrokePositionVectorUnique PredictedPositions;
    UIStroke(UIStrokeInt strokeId, UIStrokeTime timestamp, UIStrokeInputType inputType, UIStrokePhase strokePhase);
    UIStroke(UIStrokeInt strokeId, UIStrokeTime timestamp, UIStrokeInputType inputType, UIStrokePhase strokePhase, UIStrokeInt tapCount, UIStrokeFloat majorRadiusTolerance, UIStrokeFloat maxPossibleForce);
    UIStroke();
    UIStroke(UIStroke&& stroke);
    UIStroke(const UIStroke& stroke);
    UIStroke& operator=(UIStroke&& stroke);
    UIStroke& operator=(const UIStroke& stroke);
    void AddPosition(UIStrokePosition position);
    UIStrokePosition* GetLastPosition();
    UIStrokeManagerWeak StrokeManager;
    void PurgePredictedPositions();
    void OnCompleted();
    void OnCancelled();
    void Shrink();
    void TrimAndSmooth();
private:
    void EnsurePositions();
    void EnsurePredictedPositions();
    UIStrokeInt _SmoothedBookmark;
} UIStroke;

using UIStrokeVector = std::vector<UIStroke>;

class UIStrokeManager : std::enable_shared_from_this<UIStrokeManager>
{
public:
    UIStrokeManager();
    UIStrokeManager(UIStrokeManager&& strokeManager);
    UIStrokeManager(const UIStrokeManager& strokeManager);
    UIStrokeManager& operator=(UIStrokeManager&& strokeManager);
    UIStrokeManager& operator=(const UIStrokeManager& strokeManager);
    ~UIStrokeManager();

    UIStrokeSettingsShared Settings;
    UIStrokeVector ActiveStrokes;
    UIStrokeVector StrokeArchive;

    bool AddActiveStroke(UIStroke stroke);
    UIStroke* GetActiveStroke(UIStrokeInt strokeId);
    bool CancelActiveStroke(UIStrokeInt strokeId);
    bool EndActiveStroke(UIStrokeInt strokeId);
private:
};

#endif /* UIStrokeLib_h */

