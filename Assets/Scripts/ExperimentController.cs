using System.Collections;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.XR;

public class ExperimentController : MonoBehaviour
{
    public Transform rightHandController;
    public MovementLogger dataLogger;
    public TargetController targetController;
    public PenaltyController penaltyController;
    public RewardEvaluator rewardEvaluator;
    public int totalTrials = 10;

    private int currentTrial = 0;
    private InputDevice rightHandDevice;

    void Start()
    {
        rightHandDevice = InputDevices.GetDeviceAtXRNode(XRNode.RightHand);
        if (!rightHandDevice.isValid)
        {
            Debug.LogWarning("RightHand XR device not valid at Start. Will try to reconnect during CaptureMovement.");
        }

        StartCoroutine(DelayThenRun());
    }

    IEnumerator DelayThenRun()
    {
        Debug.Log("Entered DelayThenRun");
        while (targetController == null || targetController.targets == null || targetController.targets.Count < 9)
        {
            Debug.Log("Waiting for targets to be initialized...");
            yield return null;
        }

        Debug.Log("Targets ready. Starting trials...");
        yield return new WaitForSeconds(0.5f);
        StartCoroutine(RunTrials());
    }

    IEnumerator RunTrials()
    {
        Debug.Log("Entered RunTrials()");

        if (TrialManager.Instance != null && TrialManager.Instance.currentTrial >= TrialManager.Instance.totalTrials)
        {
            Debug.Log("All trials complete. Not loading ExperimentScene anymore.");
            yield break;
        }

        Debug.Log($"[RunTrials] Trial {TrialManager.Instance.currentTrial}/{TrialManager.Instance.totalTrials}");

        int targetCount = targetController.targets.Count;
        if (targetCount == 0)
        {
            Debug.LogError("No targets were generated. Aborting trial.");
            yield break;
        }

        int randomIndex = Random.Range(0, targetCount);
        Debug.Log($"Target Count: {targetCount}, Random Index: {randomIndex}");

        targetController.ActivateOnly(randomIndex);
        GameObject activeTarget = targetController.GetTarget(randomIndex);

        penaltyController.ApplyPenalty(activeTarget);

        yield return new WaitForSeconds(2f);

        yield return StartCoroutine(CaptureMovement(activeTarget));

        targetController.ActivateOnly(-1);
        penaltyController.ClearPenalty();

        Debug.Log($"Current Points: {GameManager.Instance.Points}");

        // Increment trial count
        TrialManager.Instance.currentTrial++;
        // Return to start scene
        Debug.Log("Returning to StartScene...");
        StartCoroutine(LoadSceneCleanly("SampleScene"));
    }

    IEnumerator LoadSceneCleanly(string sceneName)
    {
        var loadOp = SceneManager.LoadSceneAsync(sceneName);
        loadOp.allowSceneActivation = false;

        yield return new WaitForSeconds(0.1f);  // Small pause to let Unity clean up

        loadOp.allowSceneActivation = true;
    }


    IEnumerator CaptureMovement(GameObject target)
    {
        Debug.Log($"[CaptureMovement] Starting for target: {target?.name}");

        bool pointEvaluated = false;
        Vector3 prevPos = rightHandController.position;

        while (!pointEvaluated)
        {
            if (!rightHandDevice.isValid)
            {
                rightHandDevice = InputDevices.GetDeviceAtXRNode(XRNode.RightHand);
            }

            Vector3 velocity = Vector3.zero;

            if (rightHandDevice.isValid && rightHandDevice.TryGetFeatureValue(CommonUsages.deviceVelocity, out velocity))
            {
                Debug.Log($"Controller velocity (XR): {velocity.magnitude}");
            }
            else
            {
                // Fallback manual velocity
                Vector3 currentPos = rightHandController.position;
                velocity = (currentPos - prevPos) / Time.deltaTime;
                prevPos = currentPos;
                Debug.Log($"Controller velocity (manual): {velocity.magnitude}");
            }

            if (velocity.magnitude < 0.01f)
            {
                Vector3 reachEnd = rightHandController.position;

                dataLogger.LogTrial(
                    currentTrial + 1,
                    Vector3.zero,  // Replace with actual start pos if tracked
                    reachEnd,
                    Time.time,
                    Time.time,
                    velocity
                );

                rewardEvaluator.Evaluate(reachEnd, target.transform.position, GameManager.Instance.PenaltyPos);
                pointEvaluated = true;
            }

            yield return null;
        }
    }
}
