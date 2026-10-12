using UnityEngine;
using UnityEngine.Video;

[CreateAssetMenu(fileName = "New Tip", menuName = "ScriptableObjects/New Tip")]
public class TipObject : ScriptableObject
{
	public VideoClip tipVideoClip;

	public string GetTipText()
	{
		return Singleton<LocalizationSystem>.Instance.GetIDString(base.name);
	}
}
