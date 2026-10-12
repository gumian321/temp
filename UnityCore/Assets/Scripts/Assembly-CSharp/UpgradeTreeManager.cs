using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public class UpgradeTreeManager : SceneSingleton<UpgradeTreeManager>
{
	[SerializeField]
	private GameObject selectedButton;

	[SerializeField]
	private GameObject backButton;

	[SerializeField]
	private GameObject RarityObject;

	[SerializeField]
	private GameObject MetaPointsObject;

	[SerializeField]
	private Vector3 TreeCamPos;

	[Space]
	[Header("LayerMasks")]
	[SerializeField]
	private LayerMask nodeActiveLayerMask;

	[SerializeField]
	private LayerMask nodeDeactiveLayerMask;

	[SerializeField]
	private Vector3 zoomInOffset;

	[SerializeField]
	private float zoomInSize;

	private List<UpgradeTreeNode> upgradeTreeNodesList;

	private UpgradeTreeNode currentUpgradeTreeNode;

	private MainMenuCameraManager mainMenuCameraManager;

	private UpgradeTreeDataStore UTDS;

	private bool isNodeActivated;

	private bool isTreeActivated;

	private int TreeNodesCount;

	private int TreeNodesUnlockedCount;

	private void Start()
	{
		upgradeTreeNodesList = Object.FindObjectsOfType<UpgradeTreeNode>().ToList();
		mainMenuCameraManager = SceneSingleton<MainMenuCameraManager>.Instance;
		UTDS = Singleton<UpgradeTreeDataStore>.Instance;
		CountTreeNodes();
	}

	public void ShowTree()
	{
		SceneSingleton<MainMenuManager>.Instance.SetOnEscKeyPressed(DeActivateTree);
		PlayerPrefs.SetInt("GoToLab", 0);
		isTreeActivated = false;
		SceneSingleton<MainMenuCameraManager>.Instance.SetCamTargetPos(TreeCamPos, () =>
		{
			GetComponent<CanvasGroup>().interactable = true;
			EventSystem.current.SetSelectedGameObject(selectedButton);
			ActivateTree();
			isTreeActivated = true;
		});
		SceneSingleton<MainMenuCameraManager>.Instance.SetCamTargetZoom();
	}

	private void ActivateTree()
	{
		backButton.GetComponent<Button>().interactable = true;
		TweenController.KillTweens(backButton.transform);
		TweenController.ScaleV3(backButton.transform, 0f, 1f, TweenDuration.Super_Short, ignoreTimeScale: true);
		TweenController.KillTweens(RarityObject.transform);
		TweenController.ScaleV3(RarityObject.transform, 0f, 1f, TweenDuration.Super_Short, ignoreTimeScale: true);
		TweenController.KillTweens(MetaPointsObject.transform);
		TweenController.ScaleV3(MetaPointsObject.transform, 0f, 1f, TweenDuration.Super_Short, ignoreTimeScale: true);
	}

	public void DeActivateTree()
	{
		SceneSingleton<MainMenuManager>.Instance.SetOnEscKeyPressed(null);
		backButton.GetComponent<Button>().interactable = false;
		GetComponent<CanvasGroup>().interactable = false;
		isTreeActivated = false;
		TweenController.KillTweens(backButton.transform);
		TweenController.KillTweens(RarityObject.transform);
		TweenController.KillTweens(MetaPointsObject.transform);
		backButton.transform.localScale = Vector3.zero;
		RarityObject.transform.localScale = Vector3.zero;
		MetaPointsObject.transform.localScale = Vector3.zero;
		SceneSingleton<MainMenuManager>.Instance.ShowMainMenu();
	}

	public void BackNode()
	{
		if (currentUpgradeTreeNode != null)
		{
			currentUpgradeTreeNode.DeactivateNode();
			currentUpgradeTreeNode = null;
		}
	}

	public bool CanAvctivateNode()
	{
		if (!isNodeActivated)
		{
			return isTreeActivated;
		}
		return false;
	}

	public void ActivateNode(UpgradeTreeNode upgradeTreeNode)
	{
		SceneSingleton<MainMenuManager>.Instance.SetOnEscKeyPressed(BackNode);
		backButton.GetComponent<Button>().interactable = false;
		currentUpgradeTreeNode = upgradeTreeNode;
		isNodeActivated = true;
		HideAllNodes(upgradeTreeNode);
		TweenController.KillTweens(backButton.transform);
		TweenController.ScaleV3(backButton.transform, 1f, 0f, TweenDuration.Very_Short, ignoreTimeScale: true);
		mainMenuCameraManager.SetCamTargetPos(GetZoomPos(upgradeTreeNode.transform));
		mainMenuCameraManager.SetCamTargetZoom(zoomInSize);
		mainMenuCameraManager.SetCamMask(nodeActiveLayerMask);
	}

	public void DeactivateNode()
	{
		backButton.GetComponent<Button>().interactable = true;
		SceneSingleton<MainMenuManager>.Instance.SetOnEscKeyPressed(DeActivateTree);
		isNodeActivated = false;
		ShowAllNodes();
		SceneSingleton<MainMenuCameraManager>.Instance.SetCamTargetPos(TreeCamPos);
		SceneSingleton<MainMenuCameraManager>.Instance.SetCamTargetZoom();
		TweenController.KillTweens(backButton.transform);
		TweenController.ScaleV3(backButton.transform, 0f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true);
		mainMenuCameraManager.SetCamMask(nodeDeactiveLayerMask);
		EventSystem.current.SetSelectedGameObject(currentUpgradeTreeNode.gameObject);
		currentUpgradeTreeNode = null;
	}

	private void ShowAllNodes()
	{
		foreach (UpgradeTreeNode upgradeTreeNodes in upgradeTreeNodesList)
		{
			upgradeTreeNodes.ShowNode();
		}
	}

	private void HideAllNodes(UpgradeTreeNode upgradeTreeNode)
	{
		foreach (UpgradeTreeNode upgradeTreeNodes in upgradeTreeNodesList)
		{
			if (upgradeTreeNodes != upgradeTreeNode)
			{
				upgradeTreeNodes.HideNode();
			}
		}
	}

	private Vector3 GetZoomPos(Transform transform)
	{
		return transform.position + zoomInOffset;
	}

	public int GetTreeNodesUnlockedCount()
	{
		return TreeNodesUnlockedCount;
	}

	private void CountTreeNodes()
	{
		TreeNodesCount = 0;
		TreeNodesUnlockedCount = 0;
		foreach (UpgradeTreeNode upgradeTreeNodes in upgradeTreeNodesList)
		{
			TreeNodesCount += upgradeTreeNodes.GetNodeRewardsList().Count;
			foreach (Reward nodeRewards in upgradeTreeNodes.GetNodeRewardsList())
			{
				if (nodeRewards.IsRewardUnlocked())
				{
					TreeNodesUnlockedCount++;
				}
			}
		}
	}

	public List<Reward> GetTreeRewards()
	{
		if (upgradeTreeNodesList == null)
		{
			upgradeTreeNodesList = Object.FindObjectsOfType<UpgradeTreeNode>().ToList();
		}
		List<Reward> list = new List<Reward>();
		foreach (UpgradeTreeNode upgradeTreeNodes in upgradeTreeNodesList)
		{
			List<Reward> list2 = new List<Reward>(upgradeTreeNodes.GetNodeRewardsList());
			list2.Reverse();
			list.AddRange(list2);
		}
		return list;
	}

	public void TreeNodeUnlocked()
	{
		TreeNodesUnlockedCount++;
		if (FBPP.GetInt("HalfTreeUnlocked") == 0 && TreeNodesUnlockedCount >= TreeNodesCount / 2)
		{
			Singleton<GameAchievementsManager>.Instance?.Complete_LabHalfUnlocked();
			if (Singleton<AnalyticsManager>.Instance != null)
			{
				Singleton<AnalyticsManager>.Instance.CallLabHalfUnlockedEvent();
			}
			FBPP.SetInt("HalfTreeUnlocked", 1);
		}
		if (FBPP.GetInt("FullTreeUnlocked") == 0 && TreeNodesUnlockedCount >= TreeNodesCount)
		{
			Singleton<GameAchievementsManager>.Instance?.Complete_LabFullUnlocked();
			if (Singleton<AnalyticsManager>.Instance != null)
			{
				Singleton<AnalyticsManager>.Instance.CallLabFullyUnlockedEvent();
			}
			FBPP.SetInt("FullTreeUnlocked", 1);
		}
		if (FBPP.GetInt("FirstNodeTreeUnlocked") == 0 && IsFirstNodesUnlocked())
		{
			if (Singleton<AnalyticsManager>.Instance != null)
			{
				Singleton<AnalyticsManager>.Instance.CallLabFirstNodeUnlockedEvent();
			}
			FBPP.SetInt("FirstNodeTreeUnlocked", 1);
		}
		if (IsRarityUnlocked(RarityTypes.Common))
		{
			Singleton<GameAchievementsManager>.Instance?.Complete_LabCommonUnlocked();
		}
		if (IsRarityUnlocked(RarityTypes.Rare))
		{
			Singleton<GameAchievementsManager>.Instance?.Complete_LabRareUnlocked();
		}
		if (IsRarityUnlocked(RarityTypes.Epic))
		{
			Singleton<GameAchievementsManager>.Instance?.Complete_LabEpicUnlocked();
		}
		if (IsRarityUnlocked(RarityTypes.Legendery))
		{
			Singleton<GameAchievementsManager>.Instance?.Complete_LabLegendaryUnlocked();
		}
		SaveSystem.SaveGame();
	}

	private bool IsFirstNodesUnlocked()
	{
		foreach (UpgradeTreeNode upgradeTreeNodes in upgradeTreeNodesList)
		{
			if (!upgradeTreeNodes.IsFirstNodeUnlocked())
			{
				return false;
			}
		}
		return true;
	}

	private bool IsRarityUnlocked(RarityTypes rarityType)
	{
		foreach (UpgradeTreeNode upgradeTreeNodes in upgradeTreeNodesList)
		{
			if (!upgradeTreeNodes.IsRarityUnlocked(rarityType))
			{
				return false;
			}
		}
		return true;
	}

	private void PrintTotalTreePrice()
	{
		int num = 0;
		foreach (UpgradeTreeNode upgradeTreeNodes in upgradeTreeNodesList)
		{
			num += upgradeTreeNodes.GetTotalNodePrice();
		}
		MonoBehaviour.print(num);
	}
}
