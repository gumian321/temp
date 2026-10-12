using UnityEngine;

public interface IMissionModeManager
{
	void SetUpMode();

	void StartMode();

	void EndMode(bool isPlayerWon);

	Transform GetModeTarget();

	int GetMissionCompletedRating();

	int GetBonusRating(bool isPlayerWon);
}
