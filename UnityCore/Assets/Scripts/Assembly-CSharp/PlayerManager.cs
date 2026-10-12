using UnityEngine;

public class PlayerManager : SceneSingleton<PlayerManager>
{
	private Transform playerTransform;

	private float ShipSize;

	private void Start()
	{
		playerTransform = base.transform;
	}

	public void Reset()
	{
		SceneSingleton<PlayerCenterRadar>.Instance.ActivateRadar();
		SceneSingleton<PlayerEngineBoostController>.Instance.Setup();
		SceneSingleton<PlayerMovement>.Instance.Setup();
		SceneSingleton<PlayerBuildingManager>.Instance.SetShipSizeLimits();
		SceneSingleton<PlayerBuildingManager>.Instance.SpawnShipCenterPiece(Singleton<PlayerDataStore>.Instance.HQCore);
		if (SceneSingleton<GameMissionManager>.Instance.IsOffsetPlayer())
		{
			playerTransform.position = new Vector2(SceneSingleton<GameMissionManager>.Instance.GetPlayerOffset(), 0f);
		}
	}

	public void SetUpMainCore(CoreController mainCoreController)
	{
		mainCoreController.GetComponent<BoxCollider2D>().size *= 2f;
		SceneSingleton<PlayerTurretManager>.Instance.BuildPlayerTurret(mainCoreController, Singleton<PlayerDataStore>.Instance.GetMainTurretCore());
		SceneSingleton<PlayerCoresManager>.Instance.RefreshMainCoreHealth();
		SceneSingleton<PlayerDronesManager>.Instance.BuildDrones();
		SceneSingleton<PlayerDronesManager>.Instance.SetMainParent(mainCoreController.transform);
	}

	public void SetShipSize(int size)
	{
		ShipSize = size;
	}

	public Transform GetPlayerTransform()
	{
		if (playerTransform == null)
		{
			playerTransform = base.transform;
		}
		return playerTransform;
	}

	public float GetPlayerShipSize()
	{
		return ShipSize;
	}

	public DetectionType GetPlayerDetectionType()
	{
		return DetectionType.Player;
	}
}
