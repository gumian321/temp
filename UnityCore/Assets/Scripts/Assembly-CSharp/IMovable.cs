using UnityEngine;

public interface IMovable
{
	void SonicWavePush(Vector3 targetPos);

	void StartBlackHoleSuck(Vector3 targetPos, float suckForce);

	void StopBlackHoleSuck();
}
