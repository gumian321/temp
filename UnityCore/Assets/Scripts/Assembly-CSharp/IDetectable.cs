using UnityEngine;

public interface IDetectable
{
	Transform GetDetectionTransform();

	bool IsDetectionType(DetectionType detectionType);
}
