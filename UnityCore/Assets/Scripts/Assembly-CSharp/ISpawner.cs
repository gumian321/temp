public interface ISpawner
{
	void SetUp(bool isActivated, bool isPlayerTargeting);

	void PauseSpawner();

	void ResumeSpawner();

	void BossActivated();

	void BossDectivated();
}
