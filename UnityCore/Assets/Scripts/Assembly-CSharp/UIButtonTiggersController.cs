using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public class UIButtonTiggersController : MonoBehaviour
{
	private EventTrigger eventTrigger;

	private Button button;

	[SerializeField]
	private AudioClipTypes clickAudioClip = AudioClipTypes.UI_Click;

	[SerializeField]
	private AudioClipTypes hoverAudioClip = AudioClipTypes.UI_Hover;

	private void Awake()
	{
		button = GetComponent<Button>();
		SetUpEventTriggers();
	}

	private void SetUpEventTriggers()
	{
		eventTrigger = base.gameObject.AddComponent<EventTrigger>();
		EventTrigger.Entry entry = new EventTrigger.Entry();
		entry.eventID = EventTriggerType.PointerClick;
		entry.callback.AddListener((BaseEventData eventData) =>
		{
			OnPointerClick();
		});
		eventTrigger.triggers.Add(entry);
		entry = new EventTrigger.Entry();
		entry.eventID = EventTriggerType.PointerExit;
		entry.callback.AddListener((BaseEventData eventData) =>
		{
			OnPointerExit();
		});
		eventTrigger.triggers.Add(entry);
		entry = new EventTrigger.Entry();
		entry.eventID = EventTriggerType.PointerEnter;
		entry.callback.AddListener((BaseEventData eventData) =>
		{
			OnPointerEnter();
		});
		eventTrigger.triggers.Add(entry);
	}

	public void OnPointerClick()
	{
		if (button.interactable)
		{
			Singleton<AudioManager>.Instance.PlaySFX(clickAudioClip);
		}
	}

	public void OnPointerEnter()
	{
		if (button.interactable)
		{
			Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Hand);
			Singleton<AudioManager>.Instance.PlaySFX(hoverAudioClip);
		}
	}

	public void OnPointerExit()
	{
		if (button.interactable)
		{
			Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Normal);
		}
	}
}
