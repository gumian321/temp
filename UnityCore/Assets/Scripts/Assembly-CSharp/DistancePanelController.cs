using TMPro;
using UnityEngine;

public class DistancePanelController : MonoBehaviour
{
	[SerializeField]
	private TextMeshProUGUI distanceText;

	private Transform target;

	private Transform Goal;

	private bool isOff = true;

	public void SetController(Transform target, Transform Goal)
	{
		this.target = target;
		this.Goal = Goal;
		isOff = false;
	}

	private void FixedUpdate()
	{
		if (!isOff)
		{
			distanceText.text = ((int)Vector2.Distance(target.position, Goal.position)).ToString();
		}
	}
}
