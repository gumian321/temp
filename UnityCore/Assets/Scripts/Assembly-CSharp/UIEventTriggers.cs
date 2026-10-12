using System;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.Events;
using UnityEngine.UI;

public class UIEventTriggers : MonoBehaviour, ISelectHandler, IEventSystemHandler, IDeselectHandler, ISubmitHandler, IMoveHandler, IPointerClickHandler, IPointerEnterHandler, IPointerExitHandler
{
	private Selectable selectable;

	[SerializeField]
	public GameObject handSelector;

	private bool isSelected;

	[SerializeField]
	public UnityEvent OnPointerClickEvent;

	[SerializeField]
	public UnityEvent OnPointerEnterEvent;

	[SerializeField]
	public UnityEvent OnPointerExitEvent;

	[SerializeField]
	private bool IsDebug;

	private void Awake()
	{
		selectable = GetComponent<Selectable>();
	}

	private void OnEnable()
	{
		CurserManager instance = Singleton<CurserManager>.Instance;
		instance.OnCurserMove = (Action)Delegate.Combine(instance.OnCurserMove, new Action(OnCurserMove));
		CurserManager instance2 = Singleton<CurserManager>.Instance;
		instance2.OnCurserHide = (Action)Delegate.Combine(instance2.OnCurserHide, new Action(OnCurserHide));
	}

	private void OnDisable()
	{
		CurserManager instance = Singleton<CurserManager>.Instance;
		instance.OnCurserMove = (Action)Delegate.Remove(instance.OnCurserMove, new Action(OnCurserMove));
		CurserManager instance2 = Singleton<CurserManager>.Instance;
		instance2.OnCurserHide = (Action)Delegate.Remove(instance2.OnCurserHide, new Action(OnCurserHide));
	}

	public void OnCurserMove()
	{
		if (handSelector != null)
		{
			handSelector.SetActive(value: false);
		}
	}

	public void OnCurserHide()
	{
		if (isSelected && handSelector != null)
		{
			handSelector.SetActive(value: true);
		}
	}

	public void OnCanvasGroupChanged()
	{
		if (handSelector != null)
		{
			handSelector.SetActive(value: false);
		}
	}

	public void OnPointerClick(PointerEventData eventData)
	{
		if (!(selectable != null) || selectable.IsInteractable())
		{
			if (OnPointerClickEvent != null)
			{
				OnPointerClickEvent.Invoke();
			}
			if (handSelector != null)
			{
				handSelector.SetActive(value: false);
			}
			if (IsDebug)
			{
				Debug.Log("OnPointerClick");
			}
		}
	}

	public void OnPointerEnter(PointerEventData eventData)
	{
		if (!(selectable != null) || selectable.IsInteractable())
		{
			if (OnPointerEnterEvent != null)
			{
				OnPointerEnterEvent.Invoke();
			}
			if (handSelector != null)
			{
				handSelector.SetActive(!Singleton<CurserManager>.Instance.isCurserActive);
			}
			if (IsDebug)
			{
				Debug.Log("OnPointerEnter");
			}
		}
	}

	public void OnPointerExit(PointerEventData eventData)
	{
		if (!(selectable != null) || selectable.IsInteractable())
		{
			if (OnPointerExitEvent != null)
			{
				OnPointerExitEvent.Invoke();
			}
			if (handSelector != null)
			{
				handSelector.SetActive(value: false);
			}
			if (IsDebug)
			{
				Debug.Log("OnPointerExit");
			}
		}
	}

	public void OnSubmit(BaseEventData eventData)
	{
		isSelected = false;
		OnPointerClick(null);
		if (handSelector != null)
		{
			handSelector.SetActive(value: false);
		}
		if (IsDebug)
		{
			Debug.Log("OnSubmit");
		}
	}

	public void OnMove(AxisEventData eventData)
	{
		isSelected = false;
		Singleton<CurserManager>.Instance.HideMouseCurser();
	}

	public void OnSelect(BaseEventData eventData)
	{
		isSelected = true;
		OnPointerEnter(null);
		if (IsDebug)
		{
			Debug.Log("OnSelect");
		}
	}

	public void OnDeselect(BaseEventData eventData)
	{
		isSelected = false;
		OnPointerExit(null);
		if (IsDebug)
		{
			Debug.Log("OnDeselect");
		}
	}
}
