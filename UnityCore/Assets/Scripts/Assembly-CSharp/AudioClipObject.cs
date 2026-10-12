using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(fileName = "New AudioObject", menuName = "ScriptableObjects/Audio Clip Object")]
public class AudioClipObject : ScriptableObject
{
	public AudioClipTypes audioClipEnum;

	public List<AudioClip> audioClipList;

	public int copiesPlayedAtOnce = 5;

	[Range(0f, 1f)]
	public float volume = 1f;

	public bool isLoopable;

	public AudioClip GetAudioClip()
	{
		return audioClipList[Random.Range(0, audioClipList.Count)];
	}
}
