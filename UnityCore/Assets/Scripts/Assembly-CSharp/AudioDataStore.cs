using System.Collections.Generic;
using UnityEngine;

public class AudioDataStore : Singleton<AudioDataStore>
{
	public List<AudioClip> MainMenuBackgroundAudioClipsList;

	public List<AudioClip> InGameAudioClipsList;

	public List<AudioClip> InGameBossAudioClipsList;
}
