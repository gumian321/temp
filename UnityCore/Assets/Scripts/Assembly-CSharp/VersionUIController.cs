using TMPro;
using UnityEngine;

public class VersionUIController : MonoBehaviour
{
	public static VersionUIController Instance;

	[SerializeField]
	private TextMeshProUGUI versionText;

	private void Awake()
	{
		versionText.text = Application.productName + " v" + Application.version;
	}
}
