using TMPro;
using UnityEngine;

public class PlayerStatsUIController : SceneSingleton<PlayerStatsUIController>
{
	[SerializeField]
	private TextMeshProUGUI shipSpeedText;

	[SerializeField]
	private TextMeshProUGUI shipBoostText;

	[SerializeField]
	private TextMeshProUGUI partDamageText;

	[SerializeField]
	private TextMeshProUGUI partRangeText;

	[SerializeField]
	private TextMeshProUGUI partRateText;

	[SerializeField]
	private TextMeshProUGUI partHealthText;

	[SerializeField]
	private TextMeshProUGUI hqDamageText;

	private void Start()
	{
		SetUIState(flag: false);
	}

	public void SetUIState(bool flag)
	{
		if (flag)
		{
			RefreshUI();
			TweenController.ScaleV3(base.transform, 0f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true);
		}
		else
		{
			TweenController.ScaleV3(base.transform, 1f, 0f, TweenDuration.Very_Short, ignoreTimeScale: true);
		}
	}

	public void RefreshUI()
	{
		shipSpeedText.text = GetPercent(Singleton<PlayerDataStore>.Instance.GetMainCoreSpeedPercent());
		shipBoostText.text = GetPercent(Singleton<PlayerDataStore>.Instance.GetMainCoreBoostPercent());
		partDamageText.text = GetPercent(Singleton<PlayerDataStore>.Instance.GetCoresDamagePercent());
		partRangeText.text = GetPercent(Singleton<PlayerDataStore>.Instance.GetCoresRangePercent());
		partRateText.text = GetPercent(Singleton<PlayerDataStore>.Instance.GetCoresRateOfFirePercent());
		partHealthText.text = GetPercent(Singleton<PlayerDataStore>.Instance.GetCoresHealthPercent());
		hqDamageText.text = GetPercent(Singleton<PlayerDataStore>.Instance.GetMainCoreDamagePercent());
	}

	public string GetPercent(float percent)
	{
		int num = (int)(percent * 100f) + 100;
		if (num > 0)
		{
			return "+" + num + "%";
		}
		return "-" + num + "%";
	}
}
