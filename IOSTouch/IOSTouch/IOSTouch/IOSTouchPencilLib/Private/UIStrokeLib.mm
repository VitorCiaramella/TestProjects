//
//  UIStrokeLib.cpp
//  IOSTouch
//
//  Created by Vitor Ciaramella on 12/20/18.
//  Copyright © 2018 Vitor Ciaramella. All rights reserved.
//

#include <iterator>

#include "../Public/UIStrokeLib.h"

inline static UIStrokePoint PointSubtract(UIStrokePoint point1, UIStrokePoint point2)
{
    return UIStrokePointMake(point1.x-point2.x,point1.y-point2.y);
}

inline static UIStrokePoint PointAdd(UIStrokePoint point1, UIStrokePoint point2)
{
    return UIStrokePointMake(point1.x+point2.x,point1.y+point2.y);
}

inline static UIStrokePoint PointScale(UIStrokePoint point1, UIStrokeFloat scale)
{
    return UIStrokePointMake(point1.x*scale,point1.y*scale);
}

inline static UIStrokeFloat GetVectorMagnitute(UIStrokePoint vector)
{
    return sqrt(pow(vector.x,2.0)+pow(vector.y,2.0));
}

inline static UIStrokeFloat GetPointDistance(UIStrokePoint point1, UIStrokePoint point2)
{
    return GetVectorMagnitute(PointSubtract(point1,point2));
}

/********************************
 MARK: UIStrokeSettings
 ********************************/
UIStrokeSettings::UIStrokeSettings()
{
    this->ArchiveNonActiveStrokes = false;
    this->KeepStrokePositionPropertyChangeLog = false;
    this->MinimumStrokePositionDistance = 1.0;
    this->CalculateSmoothBezierControlPoints = true;
    this->CatmullRomAlpha = 0.5;
    this->CollectDirectInput = true;
    this->CollectIndirectInput = false;
    this->CollectPencilInput = true;
    this->CollectForce = true;
    this->CollectAltitudeAngle = false;
    this->CollectAzimuthAngle = false;
    this->CollectLocation = true;
    this->CollectPreciseLocation = false;
    this->CollectCoalescedTouches = true;
    this->CollectPredictedTouches = true;
    this->CollectTouchRadius = true;
    this->LocationSensitivity = 1.0;
    this->PreciseLocationSensitivity = 1.0;
    this->ForceSensitivity = 0.1;
    this->AltitudeAngleSensitivity = M_PI/180.0;
    this->AzimuthAngleSensitivity = M_PI/180.0;
    this->MinTouchRadiusForForceSimulation = 20.0;
    this->MaxTouchRadiusForForceSimulation = 60.0;
    this->TouchRadiusSensitivity = (MaxTouchRadiusForForceSimulation-MinTouchRadiusForForceSimulation)/20;
    this->DefaultNormalizedForce = 0.2;
    this->CollectEstimatedProperties = true;
    this->UpdateEstimatedProperties = true;
    this->SimulateForceWithTouchRadius = true;
}

/********************************
 MARK: UIStroke
 ********************************/
inline void UIStroke::EnsurePositions()
{
    if (Positions == nullptr)
    {
        this->Positions = std::make_unique<UIStrokePositionVector>();
        Positions->reserve(UIStrokePositionVectorInitialCapacity);
    }
}

void UIStroke::EnsurePredictedPositions()
{
    if (PredictedPositions == nullptr)
    {
        this->PredictedPositions = std::make_unique<UIStrokePositionVector>();
        PredictedPositions->reserve(UIStrokePredictedPositionVectorInitialCapacity);
    }
}

UIStroke::UIStroke()
{
    this->StrokeId = -1;
    this->Timestamp = NAN;
    this->InputType = UIStrokeInputType::Unknown;
    this->StrokePhase = UIStrokePhase::Unknown;
    this->MajorRadiusTolerance = NAN;
    this->MaxPossibleForce = NAN;
    this->TapCount = NAN;
    this->_SmoothedBookmark = 0;
    this->Positions.reset();
    this->PredictedPositions.reset();
    this->StrokeManager.reset();
}

UIStroke::UIStroke(UIStrokeInt strokeId, UIStrokeTime timestamp, UIStrokeInputType inputType, UIStrokePhase strokePhase)
{
    this->StrokeId = strokeId;
    this->Timestamp = timestamp;
    this->InputType = inputType;
    this->StrokePhase = strokePhase;
    this->MajorRadiusTolerance = NAN;
    this->MaxPossibleForce = NAN;
    this->TapCount = NAN;
    this->_SmoothedBookmark = 0;
    this->Positions.reset();
    this->PredictedPositions.reset();
    this->StrokeManager.reset();
}

UIStroke::UIStroke(UIStrokeInt strokeId, UIStrokeTime timestamp, UIStrokeInputType inputType, UIStrokePhase strokePhase, UIStrokeInt tapCount, UIStrokeFloat majorRadiusTolerance, UIStrokeFloat maxPossibleForce)
{
    this->StrokeId = strokeId;
    this->Timestamp = timestamp;
    this->InputType = inputType;
    this->StrokePhase = strokePhase;
    this->MajorRadiusTolerance = majorRadiusTolerance;
    this->MaxPossibleForce = maxPossibleForce;
    this->TapCount = tapCount;
    this->_SmoothedBookmark = 0;
    this->Positions.reset();
    this->PredictedPositions.reset();
    this->StrokeManager.reset();
}

UIStroke::UIStroke(UIStroke&& stroke)
{
    this->StrokeId = stroke.StrokeId;
    this->Timestamp = stroke.Timestamp;
    this->InputType = stroke.InputType;
    this->StrokePhase = stroke.StrokePhase;
    this->MajorRadiusTolerance = stroke.MajorRadiusTolerance;
    this->MaxPossibleForce = stroke.MaxPossibleForce;
    this->TapCount = stroke.TapCount;
    this->_SmoothedBookmark = stroke._SmoothedBookmark;
    this->Positions = std::move(stroke.Positions);
    this->PredictedPositions = std::move(stroke.PredictedPositions);
    this->StrokeManager = stroke.StrokeManager;
}

UIStroke::UIStroke(const UIStroke& stroke)
{
    this->StrokeId = stroke.StrokeId;
    this->Timestamp = stroke.Timestamp;
    this->InputType = stroke.InputType;
    this->StrokePhase = stroke.StrokePhase;
    this->MajorRadiusTolerance = stroke.MajorRadiusTolerance;
    this->MaxPossibleForce = stroke.MaxPossibleForce;
    this->TapCount = stroke.TapCount;
    this->_SmoothedBookmark = stroke._SmoothedBookmark;
    this->Positions.reset();
    this->PredictedPositions.reset();
    if (stroke.Positions != nullptr)
    {
        this->Positions = std::make_unique<UIStrokePositionVector>(*stroke.Positions);
    }
    if (stroke.PredictedPositions != nullptr)
    {
        this->PredictedPositions = std::make_unique<UIStrokePositionVector>(*stroke.PredictedPositions);
    }
    this->StrokeManager = stroke.StrokeManager;
}

UIStroke& UIStroke::operator=(UIStroke&& stroke)
{
    this->StrokeId = stroke.StrokeId;
    this->Timestamp = stroke.Timestamp;
    this->InputType = stroke.InputType;
    this->StrokePhase = stroke.StrokePhase;
    this->MajorRadiusTolerance = stroke.MajorRadiusTolerance;
    this->MaxPossibleForce = stroke.MaxPossibleForce;
    this->TapCount = stroke.TapCount;
    this->_SmoothedBookmark = stroke._SmoothedBookmark;
    this->Positions = std::move(stroke.Positions);
    this->PredictedPositions = std::move(stroke.PredictedPositions);
    this->StrokeManager = stroke.StrokeManager;
    return *this;
}

UIStroke& UIStroke::operator=(const UIStroke& stroke)
{
    this->StrokeId = stroke.StrokeId;
    this->Timestamp = stroke.Timestamp;
    this->InputType = stroke.InputType;
    this->StrokePhase = stroke.StrokePhase;
    this->MajorRadiusTolerance = stroke.MajorRadiusTolerance;
    this->MaxPossibleForce = stroke.MaxPossibleForce;
    this->TapCount = stroke.TapCount;
    this->_SmoothedBookmark = stroke._SmoothedBookmark;
    this->Positions.reset();
    this->PredictedPositions.reset();
    if (stroke.Positions != nullptr)
    {
        this->Positions = std::make_unique<UIStrokePositionVector>(*stroke.Positions);
    }
    if (stroke.PredictedPositions != nullptr)
    {
        this->PredictedPositions = std::make_unique<UIStrokePositionVector>(*stroke.PredictedPositions);
    }
    this->StrokeManager = stroke.StrokeManager;
    return *this;
}

void UIStroke::AddPosition(UIStrokePosition position)
{
    if (position.SourceType == UIStrokePositionSourceType::Predicted)
    {
        EnsurePredictedPositions();
        this->PredictedPositions->push_back(position);
    }
    else
    {
        EnsurePositions();
        this->Positions->push_back(position);
        TrimAndSmooth();
    }
}

void UIStroke::TrimAndSmooth()
{
    auto alpha = 0.5;
    auto minDistance = UIStrokeFloat(10.0);
    auto calculateControlPoints = false;
    if (auto strokeManager = StrokeManager.lock())
    {
        alpha = strokeManager->Settings->CatmullRomAlpha;
        minDistance = strokeManager->Settings->MinimumStrokePositionDistance;
        calculateControlPoints = strokeManager->Settings->CalculateSmoothBezierControlPoints;
    }
    
    alpha = MAX(0.0, MIN(1.0, alpha));
    auto minControlPointDistance = UIStrokeFloat(minDistance/10.0);
    
    if (Positions != nullptr && Positions->size()>1)
    {
        auto startIndex = MAX(0,_SmoothedBookmark-2);
        auto positions = Positions.get();
        auto positionsCount = Positions->size();
        auto lastIndex = positionsCount-1;
        CGPoint previousPosition;
        auto lastUsefulIndex = startIndex;
        for (UIStrokeInt index=startIndex; index < positionsCount; index++)
        {
            auto currentPosition = (*positions)[index].Position;
            if (index == startIndex
                || index == lastIndex
                || GetPointDistance(previousPosition, currentPosition) > minDistance)
            {
                if (index > lastUsefulIndex)
                {
                    (*positions)[++lastUsefulIndex] = (*positions)[index];
                }
                if (calculateControlPoints && lastUsefulIndex > 2)
                {
                    auto strokePosition = &(*positions)[lastUsefulIndex-1];
                    auto previousPosition = (*positions)[lastUsefulIndex-2].Position;
                    auto previousPreviousPosition = (*positions)[lastUsefulIndex-3].Position;
                    auto nextPosition = (*positions)[lastUsefulIndex].Position;
                    strokePosition->CalculateSmoothControlPoints(nextPosition, previousPosition, previousPreviousPosition, minControlPointDistance, alpha);
                }
            }
            previousPosition = currentPosition;
        }
        _SmoothedBookmark = lastUsefulIndex;
        positions->resize(lastUsefulIndex+1);
    }
}

UIStrokePosition* UIStroke::GetLastPosition()
{
    if (Positions != nullptr)
    {
        auto positionsCount = Positions->size();
        if (positionsCount > 0)
        {
            return &(*Positions)[positionsCount-1];
        }
    }
    return nullptr;
}

void UIStroke::PurgePredictedPositions()
{
    if (PredictedPositions != nullptr)
    {
        PredictedPositions->clear();
    }
}

void UIStroke::OnCompleted()
{
    StrokePhase = UIStrokePhase::Completed;
    Shrink();
}

void UIStroke::OnCancelled()
{
    StrokePhase = UIStrokePhase::Cancelled;
    Shrink();
}

void UIStroke::Shrink()
{
    PredictedPositions.reset();
    if (Positions != nullptr)
    {
        for (UIStrokeInt i=0; i<Positions->size(); i++)
        {
            (*Positions)[i].Shrink();
        }
    }
}

/********************************
 MARK: UIStrokePosition
 ********************************/
UIStrokePosition::UIStrokePosition(UIStrokePosition&& strokePosition)
{
    this->Timestamp = strokePosition.Timestamp;
    this->Position = strokePosition.Position;
    this->SourceType = strokePosition.SourceType;
    this->Properties = strokePosition.Properties;
    this->PropertiesChangeLog.reset();
    this->SmoothControlPoint1 = strokePosition.SmoothControlPoint1;
    this->SmoothControlPoint2 = strokePosition.SmoothControlPoint2;
    if (strokePosition.PropertiesChangeLog != nullptr)
    {
        this->PropertiesChangeLog = std::move(strokePosition.PropertiesChangeLog);
    }
}

UIStrokePosition& UIStrokePosition::operator=(UIStrokePosition&& strokePosition)
{
    this->Timestamp = strokePosition.Timestamp;
    this->Position = strokePosition.Position;
    this->SourceType = strokePosition.SourceType;
    this->Properties = strokePosition.Properties;
    this->PropertiesChangeLog.reset();
    this->SmoothControlPoint1 = strokePosition.SmoothControlPoint1;
    this->SmoothControlPoint2 = strokePosition.SmoothControlPoint2;
    if (strokePosition.PropertiesChangeLog != nullptr)
    {
        this->PropertiesChangeLog = std::move(strokePosition.PropertiesChangeLog);
    }
    return *this;
}

UIStrokePosition& UIStrokePosition::operator=(const UIStrokePosition& strokePosition)
{
    this->Timestamp = strokePosition.Timestamp;
    this->Position = strokePosition.Position;
    this->SourceType = strokePosition.SourceType;
    this->Properties = strokePosition.Properties;
    this->PropertiesChangeLog.reset();
    this->SmoothControlPoint1 = strokePosition.SmoothControlPoint1;
    this->SmoothControlPoint2 = strokePosition.SmoothControlPoint2;
    if (strokePosition.PropertiesChangeLog != nullptr)
    {
        this->PropertiesChangeLog = std::make_unique<UIStrokePositionPropertiesVector>(*strokePosition.PropertiesChangeLog);
    }
    return *this;
}

UIStrokePosition::UIStrokePosition(const UIStrokePosition& strokePosition)
{
    this->Timestamp = strokePosition.Timestamp;
    this->Position = strokePosition.Position;
    this->SourceType = strokePosition.SourceType;
    this->Properties = strokePosition.Properties;
    this->PropertiesChangeLog.reset();
    this->SmoothControlPoint1 = strokePosition.SmoothControlPoint1;
    this->SmoothControlPoint2 = strokePosition.SmoothControlPoint2;
    if (strokePosition.PropertiesChangeLog != nullptr)
    {
        this->PropertiesChangeLog = std::make_unique<UIStrokePositionPropertiesVector>(*strokePosition.PropertiesChangeLog);
    }
}

UIStrokePosition::UIStrokePosition(UIStrokeTime timestamp, UIStrokePoint position, UIStrokePositionSourceType sourceType, UIStrokePositionProperties properties, bool keepPropertyChangeLog)
{
    this->Timestamp = timestamp;
    this->Position = position;
    this->SourceType = sourceType;
    this->Properties = properties;
    this->PropertiesChangeLog.reset();
    this->SetProperties(properties, keepPropertyChangeLog);
    this->SmoothControlPoint1 = UIStrokePointNull;
    this->SmoothControlPoint2 = UIStrokePointNull;
}

UIStrokePosition::UIStrokePosition(UIStrokeTime timestamp, UIStrokePoint position, UIStrokePositionSourceType sourceType)
{
    this->Timestamp = timestamp;
    this->Position = position;
    this->SourceType = sourceType;
    this->Properties = UIStrokePositionProperties();
    this->PropertiesChangeLog.reset();
    this->SmoothControlPoint1 = UIStrokePointNull;
    this->SmoothControlPoint2 = UIStrokePointNull;
}

UIStrokePosition::UIStrokePosition()
{
    this->Timestamp = NAN;
    this->Position = UIStrokePointNull;
    this->SourceType = UIStrokePositionSourceType::Unknown;
    this->Properties = UIStrokePositionProperties();
    this->PropertiesChangeLog.reset();
    this->SmoothControlPoint1 = UIStrokePointNull;
    this->SmoothControlPoint2 = UIStrokePointNull;
}

void UIStrokePosition::SetProperties(UIStrokePositionProperties& properties, bool keepPropertyChangeLog)
{
    this->Properties = properties;
    if (keepPropertyChangeLog)
    {
        if (this->PropertiesChangeLog == nullptr)
        {
            this->PropertiesChangeLog = std::make_unique<UIStrokePositionPropertiesVector>();
        }
        this->PropertiesChangeLog->push_back(properties);
    }
}

void UIStrokePosition::Shrink()
{
    if (PropertiesChangeLog != nullptr)
    {
        PropertiesChangeLog->shrink_to_fit();
    }
}

void UIStrokePosition::CalculateSmoothControlPoints(UIStrokePoint nextPosition, UIStrokePoint previousPosition, UIStrokePoint previousPreviousPosition, UIStrokeFloat minControlPointDistance, UIStrokeFloat alpha)
{
    auto distanceFromPrevious = GetPointDistance(Position, previousPosition);
    UIStrokePoint controlPoint1;
    if (distanceFromPrevious < minControlPointDistance)
    {
        controlPoint1 = previousPosition;
    }
    else
    {
        auto distanceOfPrevious = GetPointDistance(previousPosition, previousPreviousPosition);
        controlPoint1 = PointScale(Position, pow(distanceOfPrevious, 2*alpha));
        controlPoint1 = PointSubtract(controlPoint1, PointScale(previousPreviousPosition, pow(distanceFromPrevious, 2*alpha)));
        controlPoint1 = PointAdd(controlPoint1, PointScale(previousPosition,(2*pow(distanceOfPrevious, 2*alpha) + 3*pow(distanceOfPrevious, alpha)*pow(distanceFromPrevious, alpha) + pow(distanceFromPrevious, 2*alpha))));
        controlPoint1 = PointScale(controlPoint1, 1.0 / (3*pow(distanceOfPrevious, alpha)*(pow(distanceOfPrevious, alpha)+pow(distanceFromPrevious, alpha))));
    }
    SmoothControlPoint1 = controlPoint1;
    
    auto distanceToNext = GetPointDistance(Position, nextPosition);
    UIStrokePoint controlPoint2;
    if (distanceToNext < minControlPointDistance)
    {
        controlPoint2 = Position;
    }
    else
    {
        controlPoint2 = PointScale(previousPosition, pow(distanceToNext, 2*alpha));
        controlPoint2 = PointSubtract(controlPoint2, PointScale(nextPosition, pow(distanceFromPrevious, 2*alpha)));
        controlPoint2 = PointAdd(controlPoint2, PointScale(Position,(2*pow(distanceToNext, 2*alpha) + 3*pow(distanceToNext, alpha)*pow(distanceFromPrevious, alpha) + pow(distanceFromPrevious, 2*alpha))));
        controlPoint2 = PointScale(controlPoint2, 1.0 / (3*pow(distanceToNext, alpha)*(pow(distanceToNext, alpha)+pow(distanceFromPrevious, alpha))));
    }
    SmoothControlPoint2 = controlPoint2;
}

/********************************
 MARK: UIStrokePositionProperties
 ********************************/
UIStrokePositionProperties::UIStrokePositionProperties()
{
    this->Timestamp = NAN;
    this->MajorRadius = NAN;
    this->Force = NAN;
    this->AltitudeAngle = NAN;
    this->AzimuthAngle = NAN;
}

UIStrokePositionProperties::UIStrokePositionProperties(UIStrokeTime timestamp, UIStrokeFloat majorRadius, UIStrokeFloat force, UIStrokeFloat altitudeAngle, UIStrokeFloat azimuthAngle)
{
    this->Timestamp = timestamp;
    this->MajorRadius = majorRadius;
    this->Force = force;
    this->AltitudeAngle = altitudeAngle;
    this->AzimuthAngle = azimuthAngle;
}

UIStrokeFloat UIStrokePositionProperties::NormalizedForce(UIStrokeFloat maxForce, UIStrokeFloat minRadius, UIStrokeFloat maxRadius, UIStrokeFloat defaultForce)
{
    auto result = defaultForce;
    if (!isnan(Force))
    {
        result = Force / maxForce;
    }
    else if (!isnan(MajorRadius))
    {
        result = (MajorRadius-minRadius) / (maxRadius - minRadius);
    }
    return MIN(1.0,MAX(0.0, result));
}

/********************************
 MARK: UIStrokeManager
 ********************************/
UIStrokeManager::UIStrokeManager()
{
    this->ActiveStrokes.reserve(UIStrokeActiveStrokesVectorInitialCapacity);
    this->StrokeArchive.reserve(UIStrokeStrokeArchiveVectorInitialCapacity);
    this->Settings = std::make_shared<UIStrokeSettings>();
}

UIStrokeManager::UIStrokeManager(UIStrokeManager&& strokeManager)
{
    this->ActiveStrokes = strokeManager.ActiveStrokes;
    this->StrokeArchive = strokeManager.StrokeArchive;
    this->Settings = strokeManager.Settings;
}

UIStrokeManager::UIStrokeManager(const UIStrokeManager& strokeManager)
{
    this->ActiveStrokes = strokeManager.ActiveStrokes;
    this->StrokeArchive = strokeManager.StrokeArchive;
    this->Settings = strokeManager.Settings;
}

UIStrokeManager& UIStrokeManager::operator=(UIStrokeManager&& strokeManager)
{
    this->ActiveStrokes = strokeManager.ActiveStrokes;
    this->StrokeArchive = strokeManager.StrokeArchive;
    this->Settings = strokeManager.Settings;
    return *this;
}

UIStrokeManager& UIStrokeManager::operator=(const UIStrokeManager& strokeManager)
{
    this->ActiveStrokes = strokeManager.ActiveStrokes;
    this->StrokeArchive = strokeManager.StrokeArchive;
    this->Settings = strokeManager.Settings;
    return *this;
}

bool UIStrokeManager::AddActiveStroke(UIStroke stroke)
{
    ActiveStrokes.push_back(stroke);
    return true;
}

UIStrokeManager::~UIStrokeManager()
{
    
}

UIStroke* UIStrokeManager::GetActiveStroke(UIStrokeInt strokeId)
{
    auto strokeCount = ActiveStrokes.size();
    for (UIStrokeInt i=0; i<strokeCount; i++)
    {
        if (ActiveStrokes[i].StrokeId == strokeId)
        {
            return &ActiveStrokes[i];
        }
    }
    return nullptr;
}

bool UIStrokeManager::CancelActiveStroke(UIStrokeInt strokeId)
{
    auto strokeCount = ActiveStrokes.size();
    for (UIStrokeInt i=0; i<strokeCount; i++)
    {
        if (ActiveStrokes[i].StrokeId == strokeId)
        {
            ActiveStrokes[i].OnCancelled();
            ActiveStrokes.erase(ActiveStrokes.begin() + i);
            return true;
        }
    }
    return false;
}

bool UIStrokeManager::EndActiveStroke(UIStrokeInt strokeId)
{
    auto strokeCount = ActiveStrokes.size();
    for (UIStrokeInt i=0; i<strokeCount; i++)
    {
        if (ActiveStrokes[i].StrokeId == strokeId)
        {
            ActiveStrokes[i].OnCompleted();
            if (Settings->ArchiveNonActiveStrokes)
            {
                StrokeArchive.push_back(ActiveStrokes[i]);
            }
            ActiveStrokes.erase(ActiveStrokes.begin() + i);
            return true;
        }
    }
    return false;
}


