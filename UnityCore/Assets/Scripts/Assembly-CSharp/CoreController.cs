using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class CoreController : MonoBehaviour, IStunnable
{
	[SerializeField]
	protected bool disableCoreSprite;

	protected Core currentCore;

	private SpriteRenderer coreSpriteRenderer;

	private DestructibleObject coreDestructibleObject;

	private IBuilder iBuilder;

	protected GameObject coreObject;

	private CoresDataStore coresDataStore = Singleton<CoresDataStore>.Instance;

	private Transform coreTransform;

	protected float stunTimer;

	protected bool isCoreStunned;

	[HideInInspector]
	public bool isCoreDisabled;

	private DeActivateAfterTime empShockParticle;

	private ChipsContainer currentActivatedChips;

	private int highlightCount;

	private bool isSelected;

	private bool isWalled;

	private bool isClocked;

	private bool isBuildMode = true;

	public Core GetCurrentCore()
	{
		return currentCore;
	}

	public void SetCurrentCore(Core currentCore)
	{
		this.currentCore = currentCore;
	}

	public GameObject GetCoreObject()
	{
		return coreObject;
	}

	private void Awake()
	{
		coreTransform = base.transform;
	}

	public void SetCoreObject(GameObject coreTurret)
	{
		coreObject = coreTurret;
	}

	public void PreviewCore(Core core)
	{
		currentCore = core;
		currentCore.SpawnCoreObject(this);
		SetCoreRangeSprite(flag: true);
	}

	public GameObject SpawnNewCoreObject()
	{
		Object.Destroy(coreObject);
		currentCore.SpawnCoreObject(this);
		return coreObject;
	}

	public void BuildCore(IBuilder b)
	{
		iBuilder = b;
		SetCoreObject(currentCore.CoreHealth);
		currentCore.BuildCore(this);
		SetCoreRangeSprite(flag: false);
		if (disableCoreSprite)
		{
			currentCore.DisableCoreArt(this);
		}
	}

	public IBuilder GetBuilder()
	{
		return iBuilder;
	}

	public void RefreshCore()
	{
		RefreshChipsContainer();
		currentCore.RefreshCore(this);
		RefreshCoreHealth();
	}

	public void UpdateCoreHealth(float newMaxHealth)
	{
		coreDestructibleObject.UpdateObjectHealth(newMaxHealth);
	}

	public void RefreshCoreHealth()
	{
		float coreHealthPercent = Singleton<PlayerDataStore>.Instance.GetCoreHealthPercent(currentCore);
		float num = UnityEngineSystem.CalcPercent(currentCore.CoreHealth, coreHealthPercent);
		if (isWalled)
		{
			num += Singleton<CoresDataStore>.Instance.GetWalledCoreAddedHealth();
		}
		coreDestructibleObject.UpdateObjectHealth(num);
	}

	public bool IsStunned()
	{
		return isCoreDisabled;
	}

	public void Stun(float stunDuration)
	{
		stunTimer = Time.time + stunDuration;
		if (empShockParticle != null)
		{
			empShockParticle.SetDuration(stunDuration);
		}
		if (!isCoreStunned)
		{
			isCoreStunned = true;
			if (empShockParticle == null)
			{
				empShockParticle = ParticlesSystem.PlayEMPShockParticle(coreTransform, stunDuration);
			}
			currentCore.StunCore(this, isStunned: true);
		}
	}

	public void EndStun()
	{
		if (empShockParticle != null)
		{
			empShockParticle.DeActivate();
		}
		empShockParticle = null;
		isCoreStunned = false;
		currentCore.StunCore(this, isStunned: false);
	}

	public void DisableCore()
	{
		if (!isCoreDisabled)
		{
			if (currentCore != null)
			{
				currentCore.DisableCore(this);
			}
			isCoreDisabled = true;
		}
	}

	public void ActivateCore()
	{
		if (isCoreDisabled)
		{
			if (currentCore != null)
			{
				currentCore.ActivateCore(this);
			}
			isCoreDisabled = false;
		}
	}

	public virtual void FixedUpdate()
	{
		if (isCoreStunned && stunTimer < Time.time)
		{
			EndStun();
		}
	}

	private void SetCoreObject(float health)
	{
		coreSpriteRenderer = GetComponent<SpriteRenderer>();
		UpdateCoreSprite(1f);
		coreDestructibleObject = GetComponent<DestructibleObject>();
		coreDestructibleObject.SetObject(GetCoreDetectionType(), coreTransform);
		coreDestructibleObject.SetObjectHealth(DestroyCore, CoreHealthChanged, CoreHealthChanged, health);
	}

	private void UpdateCoreSprite(float percent)
	{
		if (!isWalled)
		{
			Sprite sprite = ((!(currentCore is MainCore)) ? Singleton<CoresDataStore>.Instance.GetCoreHealthSprite(percent) : Singleton<CoresDataStore>.Instance.GetMainCoreHealthSprite(percent));
			if (coreSpriteRenderer.sprite != sprite)
			{
				coreSpriteRenderer.flipX = Random.Range(0, 10) > 5;
				coreSpriteRenderer.flipY = Random.Range(0, 10) > 5;
			}
			coreSpriteRenderer.sprite = sprite;
		}
	}

	public void DestroyCore()
	{
		GetComponent<Collider2D>().enabled = false;
		iBuilder.PieceDestroyed(this);
		currentCore.DestroyCore(this);
		Object.Destroy(base.gameObject);
	}

	public void CoreHealthChanged(float currentHealth)
	{
		UpdateCoreSprite(currentHealth / coreDestructibleObject.GetMaxHealth());
	}

	public DetectionType GetCoreDetectionType()
	{
		return Singleton<DetectionDataStore>.Instance.GetDetectionType(base.gameObject);
	}

	public DetectionType GetCoreTargetDetectionType()
	{
		return Singleton<DetectionDataStore>.Instance.GetTargetDetectionType(base.gameObject);
	}

	public bool IsCoreChip()
	{
		return currentCore is ChipCore;
	}

	public ChipsContainer GetChipsContainer()
	{
		return currentActivatedChips;
	}

	private void RefreshChipsContainer()
	{
		if (!currentCore.isChipable)
		{
			return;
		}
		currentActivatedChips = new ChipsContainer();
		List<CoreController> surroundingCoreControllers = SceneSingleton<PlayerBuildingManager>.Instance.GetSurroundingCoreControllers(this);
		foreach (CoreController item in FilterChipCores(surroundingCoreControllers))
		{
			if (!item.GetCoreObject().GetComponent<ChipController>().IsDisabled())
			{
				ChipCore chipCore = (ChipCore)item.GetCurrentCore();
				currentActivatedChips.AddChip(chipCore.GetCoreChipType());
			}
		}
	}

	private List<CoreController> FilterChipCores(List<CoreController> cores)
	{
		List<CoreController> list = new List<CoreController>();
		foreach (CoreController core in cores)
		{
			if (core.GetCurrentCore() is ChipCore)
			{
				list.Add(core);
			}
		}
		return list;
	}

	public void SelectCore()
	{
		if (!isSelected)
		{
			HighLightCore();
			SetCoreRangeSprite(flag: true);
			isSelected = true;
		}
	}

	public void DeselectCore()
	{
		if (isSelected)
		{
			DisableHighLightCore();
			isSelected = false;
		}
	}

	public void HighLightCore()
	{
		highlightCount++;
		if (highlightCount <= 1)
		{
			TweenController.DOColor(coreSpriteRenderer, coresDataStore.GetHighLightedCoreColor(), TweenDuration.Super_Short, ignoreTimeScale: true);
			if (currentCore is ChipCore)
			{
				((ChipCore)currentCore).SetChipRangeState(this, state: true);
			}
			SetCoreSortingLayer(flag: true);
		}
	}

	public void DisableHighLightCore(bool snapDisable = false)
	{
		highlightCount--;
		if (!IsCoreChip())
		{
			SetCoreRangeSprite(flag: false);
		}
		SetCoreSortingLayer(flag: false);
		if (snapDisable)
		{
			highlightCount = 0;
			SetCoreRangeSprite(flag: false);
		}
		if (highlightCount <= 0)
		{
			TweenController.DOColor(coreSpriteRenderer, GetCoreColor(), TweenDuration.Super_Short, ignoreTimeScale: true);
			if (currentCore is ChipCore)
			{
				((ChipCore)currentCore).SetChipRangeState(this, state: false);
			}
			highlightCount = 0;
		}
	}

	public void SetCoreRangeSprite(bool flag)
	{
		currentCore.PreviewCore(this, flag);
	}

	public void SetCoreSortingLayer(bool flag)
	{
		if (flag)
		{
			GetComponent<SortingGroup>().sortingOrder = currentCore.coreSortingOrder + 10;
		}
		else
		{
			GetComponent<SortingGroup>().sortingOrder = currentCore.coreSortingOrder;
		}
	}

	public void AddWall()
	{
		isWalled = true;
		Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.Core_Change);
		coreSpriteRenderer.sprite = Singleton<CoresDataStore>.Instance.GetWalledCoreSprite();
		RefreshCoreHealth();
	}

	public bool CanAddWall()
	{
		return !isWalled;
	}

	public void ClockCore()
	{
		if (currentCore.isClockable && !isClocked)
		{
			isClocked = true;
			if (GetComponent<SpritePulseEffector>() != null)
			{
				GetComponent<SpritePulseEffector>().StopEffect();
			}
			coreSpriteRenderer.color = GetCoreColor();
			if (!isBuildMode)
			{
				GetComponent<Collider2D>().enabled = false;
			}
		}
	}

	public void UnClockCore()
	{
		if (currentCore.isClockable && isClocked)
		{
			isClocked = false;
			if (GetComponent<SpritePulseEffector>() != null)
			{
				GetComponent<SpritePulseEffector>().StopEffect();
			}
			coreSpriteRenderer.color = GetCoreColor();
			if (!isBuildMode)
			{
				GetComponent<Collider2D>().enabled = true;
			}
		}
	}

	private Color GetCoreColor()
	{
		if (isClocked)
		{
			return Singleton<CoresDataStore>.Instance.GetClockedCoreColor();
		}
		return Color.white;
	}

	public void EnterBuildMode()
	{
		GetComponent<Collider2D>().enabled = true;
		isBuildMode = true;
	}

	public void ExitBuildMode()
	{
		isBuildMode = false;
		if (isClocked)
		{
			GetComponent<Collider2D>().enabled = false;
		}
	}
}
