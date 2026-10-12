using System.Collections.Generic;
using UnityEngine;

public interface IBuilder
{
	void PieceDestroyed(CoreController cc);

	List<Vector3> GetSurroundingEmpty(CoreController core, List<Vector3> Surroundings);

	List<CoreController> GetSurroundingCoreControllers(CoreController core);
}
