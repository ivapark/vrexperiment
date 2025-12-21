using UnityEngine;
using UnityEngine.UI;

public class RightHandVisualState : MonoBehaviour
{
    public GameObject rightControllerVisual;
    public GameObject pokeInteractor;

    public GameObject affordanceCalloutsRight;  // keep ACTIVE
    public GameObject nearFarInteractor;

    void SetVisualsVisible(GameObject root, bool visible)
    {
        if (!root) return;

        foreach (var r in root.GetComponentsInChildren<Renderer>(true))
            r.enabled = visible;

        foreach (var c in root.GetComponentsInChildren<Canvas>(true))
            c.enabled = visible;

        foreach (var g in root.GetComponentsInChildren<Graphic>(true))
            g.enabled = visible;
    }

    public void SetStartPhase()
    {
        if (rightControllerVisual) rightControllerVisual.SetActive(false);

        // hide ONLY the affordance visuals (don’t deactivate)
        SetVisualsVisible(affordanceCalloutsRight, false);

        if (nearFarInteractor) nearFarInteractor.SetActive(false);
        if (pokeInteractor) pokeInteractor.SetActive(true);
    }

    public void SetGoPhase()
    {
        if (rightControllerVisual) rightControllerVisual.SetActive(false);
        if (pokeInteractor) pokeInteractor.SetActive(false);

        SetVisualsVisible(affordanceCalloutsRight, false);
        if (nearFarInteractor) nearFarInteractor.SetActive(false);
    }
}
