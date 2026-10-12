using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class LeaderboardUIContainer : MonoBehaviour
{
	public Text username;

	public RawImage userAvatar;

	public TextMeshProUGUI rank;

	public TextMeshProUGUI score;

	public Image userImage;

	public void SetContainer(LeaderboardData leaderboardData)
	{
		base.gameObject.SetActive(value: true);
		username.text = leaderboardData.username;
		userImage.enabled = Singleton<GameLeaderboardManager>.Instance.IsUserAccount(leaderboardData.username);
		userAvatar.texture = leaderboardData.userAvatar;
		rank.text = leaderboardData.rank + ".";
		score.text = leaderboardData.score + " pts.";
	}
}
