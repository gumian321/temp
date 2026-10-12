using UnityEngine;

public class DetectionDataStore : Singleton<DetectionDataStore>
{
	[SerializeField]
	private LayerMask MapNodeLayer;

	[Space]
	[SerializeField]
	private LayerMask playerLayer;

	[Space]
	[SerializeField]
	private LayerMask enemyLayer;

	[Space]
	[SerializeField]
	private string shieldTag = "Shield";

	[Space]
	[SerializeField]
	private string playerTag;

	public bool IsMapNodeLayer(LayerMask mask)
	{
		return GetLayerNumber(mask) == GetLayerNumber(MapNodeLayer.value);
	}

	public bool IsMapNodeLayer(int obj)
	{
		return obj == GetLayerNumber(MapNodeLayer.value);
	}

	public bool IsMapNodeLayer(GameObject obj)
	{
		return obj.layer == GetLayerNumber(MapNodeLayer.value);
	}

	public bool IsMapNodeLayer(DetectionType detectionType)
	{
		return GetLayer(detectionType) == GetLayerNumber(MapNodeLayer.value);
	}

	public int GetMapNodeLayer()
	{
		return GetLayerNumber(MapNodeLayer.value);
	}

	public bool IsPlayerLayer(LayerMask mask)
	{
		return GetLayerNumber(mask) == GetLayerNumber(playerLayer.value);
	}

	public bool IsPlayerLayer(int obj)
	{
		return obj == GetLayerNumber(playerLayer.value);
	}

	public bool IsPlayerLayer(GameObject obj)
	{
		if (obj == null)
		{
			return false;
		}
		return obj.layer == GetLayerNumber(playerLayer.value);
	}

	public bool IsPlayerLayer(DetectionType detectionType)
	{
		return GetLayer(detectionType) == GetLayerNumber(playerLayer.value);
	}

	public int GetPlayerLayer()
	{
		return GetLayerNumber(playerLayer.value);
	}

	public bool IsEnemyLayer(LayerMask mask)
	{
		return GetLayerNumber(mask) == GetLayerNumber(enemyLayer.value);
	}

	public bool IsEnemyLayer(int obj)
	{
		return obj == GetLayerNumber(enemyLayer.value);
	}

	public bool IsEnemyLayer(GameObject obj)
	{
		if (obj == null)
		{
			return false;
		}
		return obj.layer == GetLayerNumber(enemyLayer.value);
	}

	public bool IsEnemyLayer(DetectionType detectionType)
	{
		return GetLayer(detectionType) == GetLayerNumber(enemyLayer.value);
	}

	public int GetEnemyLayer()
	{
		return GetLayerNumber(enemyLayer.value);
	}

	public bool IsShieldLayer(GameObject obj)
	{
		if (obj == null)
		{
			return false;
		}
		return obj.tag == shieldTag;
	}

	public bool IsPlayer(Transform obj)
	{
		if (obj == null)
		{
			return false;
		}
		return obj.tag == playerTag;
	}

	public int GetLayer(DetectionType detectionType)
	{
		switch (detectionType)
		{
		case DetectionType.Enemy:
			return GetEnemyLayer();
		case DetectionType.Player:
			return GetPlayerLayer();
		default:
			Debug.LogError("Error in Finding Layer from " + detectionType);
			return -1;
		}
	}

	public int GetLayerNumber(LayerMask myLayer)
	{
		int num = 0;
		int num2 = myLayer.value;
		while (num2 > 1)
		{
			num2 >>= 1;
			num++;
		}
		return num;
	}

	public int GetLayerNumber(DetectionType detectionType)
	{
		if (IsPlayerLayer(detectionType))
		{
			return GetLayerNumber(playerLayer);
		}
		if (IsEnemyLayer(detectionType))
		{
			return GetLayerNumber(enemyLayer);
		}
		return 0;
	}

	public DetectionType GetDetectionType(GameObject obj)
	{
		if (IsPlayerLayer(obj))
		{
			return DetectionType.Player;
		}
		if (IsEnemyLayer(obj))
		{
			return DetectionType.Enemy;
		}
		return DetectionType.None;
	}

	public DetectionType GetTargetDetectionType(GameObject obj)
	{
		if (IsPlayerLayer(obj))
		{
			return DetectionType.Enemy;
		}
		if (IsEnemyLayer(obj))
		{
			return DetectionType.Player;
		}
		return DetectionType.None;
	}

	public DetectionType GetVSDetectionType(DetectionType DT)
	{
		return DT switch
		{
			DetectionType.Enemy => DetectionType.Player, 
			DetectionType.Player => DetectionType.Enemy, 
			_ => DetectionType.None, 
		};
	}
}
