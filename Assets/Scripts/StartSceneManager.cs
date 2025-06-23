using UnityEngine;
using UnityEngine.SceneManagement;

public class StartSceneManager : MonoBehaviour
{
    public StartZoneDetector startZone;
    public Transform rightHandController;
    public float velocityThreshold = 0.01f;  // Velocity below this means stopped
    public float requiredStillTime = 3f;     // Time required to stay still

    private float stillTimer = 0f;
    private bool loadingScene = false;
    private Rigidbody controllerRb;

    void Start()
    {
        if (rightHandController != null)
        {
            controllerRb = rightHandController.GetComponent<Rigidbody>();
            if (controllerRb == null)
                Debug.LogWarning("RightHandController has no Rigidbody. Velocity will always be zero.");
        }
        else
        {
            Debug.LogError("RightHandController not assigned in StartSceneManager!");
        }
    }

    void Update()
    {
        if (loadingScene || rightHandController == null) return;

        if (TrialManager.Instance != null && TrialManager.Instance.currentTrial >= TrialManager.Instance.totalTrials)
        {
            if (!loadingScene)  // only log once
            {
                Debug.Log("All trials complete. No more ExperimentScene loads.");
                loadingScene = true;  // mark done
            }
            return;
        }
  


        if (startZone != null && startZone.handIsInZone)
        {
            float speed = controllerRb != null ? controllerRb.velocity.magnitude : 0f;

            if (speed < velocityThreshold)
            {
                stillTimer += Time.deltaTime;
                if (stillTimer >= requiredStillTime)
                {
                    Debug.Log("Conditions met: loading ExperimentScene...");
                    loadingScene = true;
                    LoadExperimentScene();
                }
            }
            else
            {
                stillTimer = 0f;  // Reset if hand moves
            }
        }
        else
        {
            stillTimer = 0f;  // Reset if hand leaves start zone
        }
    }

    void LoadExperimentScene()
    {
        // Optionally display points or transition effects here
        SceneManager.LoadScene("ExperimentScene");
    }
}
