using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.XR;


public class ExperimentController : MonoBehaviour
{
    public Transform rightHandController;
    public MovementLogger dataLogger;
    public TargetController targetController;

    public PenaltyController PenaltyController;



    public RewardEvaluator rewardEvaluator;
    public FeedbackDisplay feedbackDisplay;
    public GameObject startCircleVisual;
    public StartZoneDetector startZoneDetector;

    public Material targetPrepMaterial;
    public Material penaltyPreorangeMaterial;
    public Material targetGoMaterial;
    public Material penaltyGoMaterial;
    public Material hitMaterial;
    public Material missMaterial;
    public Material neutralMaterial;
    public Material tooSlowMaterial;
    public Material targetTransparentMaterial;



    public int totalTrials = 10;

    private InputDevice rightHandDevice;
    private int targetSeed;       // Single seed for reproducibility
    private int usedSeedPenalty;  // Penalty seed for logging

    private List<Vector3> targetRandomSnapshot;
    private List<Vector3> penaltyRandomSnapshot;


    void Start()
    {
        // Generate one seed for all trials
        targetSeed = System.DateTime.Now.GetHashCode();
        Debug.Log($"[ExperimentController] Using Target Seed: {targetSeed}");

        rightHandDevice = InputDevices.GetDeviceAtXRNode(XRNode.RightHand);
        StartCoroutine(DelayThenRun());
    }

    IEnumerator DelayThenRun()
    {
        // Wait until targets are generated
        while (targetController == null || targetController.targets == null || targetController.targets.Count < 9)
            yield return null;

        StartCoroutine(RunTrials());
    }

    IEnumerator RunTrials()
    {
        int trialCount = 0;

        while (true)
        {
            // Fetch next trial condition
            TrialCondition condition = TrialManager.Instance.GetNextTrial();

            if (condition == null)
            {
                Debug.Log("All trials complete.");
                ShowFinalScore();
                yield break;
            }

            int conditionID = condition.targetIndex * 10 + condition.penaltyIndex;


            trialCount++;
            Debug.Log($"Starting Trial {trialCount}/{TrialManager.Instance.TotalTrialCount}");

            yield return StartCoroutine(WaitForHandToEnterStartZone());

            // Activate target
            GameObject target = targetController.GetTarget(condition.targetIndex);
            Random.InitState(targetSeed + trialCount);
            targetController.GenerateDotsForTarget(condition.targetIndex);
            targetController.ActivateOnly(condition.targetIndex);

            targetRandomSnapshot = new List<Vector3>();
            if (targetController.targetRandomValues.Count > 0)
            {
                targetRandomSnapshot.Add(targetController.targetRandomValues[0]);
                targetRandomSnapshot.Add(targetController.targetRandomValues[^1]);
            }

            // Apply penalty if applicable
            bool hasPenalty = condition.penaltyIndex != 0; // 0 = no penalty
            if (hasPenalty)
            {
                PenaltyController.ApplyPenalty(target, condition.penaltyIndex);
                usedSeedPenalty = PenaltyController.usedSeedPenalty;

                penaltyRandomSnapshot = new List<Vector3>();
                if (PenaltyController.penaltyRandomValues.Count > 0)
                {
                    penaltyRandomSnapshot.Add(PenaltyController.penaltyRandomValues[0]);
                    penaltyRandomSnapshot.Add(PenaltyController.penaltyRandomValues[^1]);
                }
            }
            else
            {
                usedSeedPenalty = -1;
                penaltyRandomSnapshot = new List<Vector3>(); // empty
            }

            Debug.Log($"[Trial {trialCount}] PenaltySeed = {usedSeedPenalty}");

            targetController.SetMaterial(targetPrepMaterial);
            if (hasPenalty) PenaltyController.SetMaterial(penaltyPreorangeMaterial);


            string outcome = "Too Slow";
            bool earlyExit = false;
            yield return StartCoroutine(WaitForStableHandInStartZone((earlyResult) =>
            {
                outcome = earlyResult;
                earlyExit = true;
            }));

            // Handle Too Early
            if (earlyExit && outcome == "Too Early")
            {
                LogPlaceholder(trialCount, conditionID, target, "Too Early");
                SetFeedback("Too Early", target, hasPenalty);
                startCircleVisual.SetActive(false);

                yield return new WaitForSeconds(1.5f); // Give time to show gray feedback

                targetController.DeactivateAll();
                if (hasPenalty) PenaltyController.ClearPenalty();

                TrialManager.Instance.ReinsertTrial(condition);
                yield return new WaitForSeconds(1.0f);
                continue;
            }


            // Capture movement
            yield return StartCoroutine(CaptureMovement(target, trialCount - 1, conditionID, 0.05f, 2.0f, (result) => outcome = result));

            if (outcome == "Too Slow" || outcome == "Invalid Start")
            {
                LogPlaceholder(trialCount, conditionID, target, outcome);
                TrialManager.Instance.ReinsertTrial(condition);
            }

            SetFeedback(outcome, target, hasPenalty);
            yield return new WaitForSeconds(1.5f);

            targetController.DeactivateAll();
            if (hasPenalty) PenaltyController.ClearPenalty();

        }
    }

    private void SetFeedback(string outcome, GameObject target, bool hasPenalty)
    {
        Color feedbackColor = outcome switch
        {
            "Hit" => Color.green,
            "Missed" or "Hit Both" => Color.red,
            "Neutral" => Color.white,
            "Invalid Start" or "Too Early" => Color.gray,
            _ => Color.gray
        };

        string message = outcome switch
        {
            "Hit" => "Hit! +300",
            "Missed" => "Missed! -500",
            "Hit Both" => "Hit Both! -200",
            "Neutral" => "Didn't hit either! +0",
            "Invalid Start" => "Invalid Start!",
            "Too Early" => "Too Early!",
            _ => "Too Slow!"
        };

        Debug.Log($"[Feedback] Outcome: {outcome}, Message: {message}");

        targetController.SetFeedbackMaterial(outcome, hitMaterial, missMaterial, neutralMaterial, tooSlowMaterial);
        if (hasPenalty)
            PenaltyController.SetFeedbackMaterial(outcome, hitMaterial, missMaterial, neutralMaterial, tooSlowMaterial);

        Vector3 forward = Camera.main.transform.forward;
        Vector3 feedbackPosition = Camera.main.transform.position + forward * 0.2f;
        feedbackDisplay.ShowMessage(message, feedbackColor, feedbackPosition);
    }

    private void LogPlaceholder(int trialCount, int conditionID, GameObject target, string result)
    {
        dataLogger.LogTrialDetails(
            trialCount,
            conditionID,
            target.transform.position,
            Vector3.zero,
            startCircleVisual.transform.position,
            startCircleVisual.transform.localScale,
            rightHandController.position,
            Vector3.zero, Vector3.zero,
            Time.time, Time.time,
            GameManager.Instance.Points,
            result,
            targetSeed + trialCount,
            targetRandomSnapshot,
            usedSeedPenalty,
            penaltyRandomSnapshot,
            new List<float>(),
            new List<Vector3>(),
            new List<Vector3>()
        );
    }

    private void ShowFinalScore()
    {
        int finalScore = GameManager.Instance.Points;
        int maxScore = totalTrials * 300;
        string finalMessage = $"All trials complete!\nTotal Score: {finalScore} / {maxScore}";
        feedbackDisplay.ShowMessage2(finalMessage, Color.yellow, Camera.main.transform.position + Camera.main.transform.forward * 0.3f);
        Debug.Log($"[Feedback] Final Score: {finalScore}");

    }


    IEnumerator WaitForHandToEnterStartZone()
    {
        startZoneDetector.handIsInZone = false;
        startCircleVisual.SetActive(true);
        while (!startZoneDetector.handIsInZone)
            yield return null;

        targetController.SetMaterial(targetPrepMaterial);
        if (PenaltyController != null && PenaltyController.GetActivePenaltyBounds().size != Vector3.zero)
            PenaltyController.SetMaterial(penaltyPreorangeMaterial);
    }

    IEnumerator WaitForStableHandInStartZone(System.Action<string> onFinishEarly = null)
    {
        while (!startZoneDetector.handIsInZone)
            yield return null;

        float stillTimer = 0f;
        Vector3 prevPos = rightHandController.position;
        float velocityThreshold = 0.05f;
        float requiredStillTime = 0.5f;

        while (true)
        {
            Vector3 currentPos = rightHandController.position;
            Vector3 velocity = (currentPos - prevPos) / Time.deltaTime;
            prevPos = currentPos;

            if (!startZoneDetector.handIsInZone)
            {
                if (velocity.magnitude >= velocityThreshold)
                {
                    onFinishEarly?.Invoke("Too Early");
                    yield break;
                }
                stillTimer = 0f;
            }
            else
            {
                if (velocity.magnitude < velocityThreshold)
                {
                    stillTimer += Time.deltaTime;
                    if (stillTimer >= requiredStillTime)
                    {
                        targetController.SetMaterial(targetGoMaterial);
                        if (PenaltyController.GetActivePenaltyBounds().size != Vector3.zero)
                            PenaltyController.SetMaterial(penaltyGoMaterial);
                        startCircleVisual.SetActive(false);
                        break;
                    }
                }
                else
                {
                    stillTimer = 0f;
                }
            }

            yield return null;
        }
    }

    IEnumerator CaptureMovement(GameObject target, int trialNumber, int conditionID, float velocityThreshold, float timeout, System.Action<string> onFinish)
    {
        if (rightHandController == null)
        {
            onFinish("Too Slow");
            yield break;
        }

        bool pointEvaluated = false;
        bool movementStarted = false;
        bool invalidAttempt = false;

        Vector3 prevPos = rightHandController.position;
        Vector3 startPos = Vector3.zero, endPos = Vector3.zero;
        float startTime = 0f, endTime = 0f, elapsed = 0f;

        List<Vector3> posSamples = new();
        List<Vector3> velSamples = new();
        List<float> timeSamples = new();

        Vector3 shownTarget = target.transform.position;
        Bounds penaltyBounds = PenaltyController.GetActivePenaltyBounds();
        Vector3 penaltyCenter = PenaltyController.GetActivePenaltyCenter();
        Vector3 startControllerPos = prevPos;

        while (!pointEvaluated)
        {
            Vector3 currentPos = rightHandController.position;
            Vector3 velocity = (currentPos - prevPos) / Time.deltaTime;
            prevPos = currentPos;
            elapsed += Time.deltaTime;

            float distanceFromStart = Vector3.Distance(currentPos, startControllerPos);

            posSamples.Add(currentPos);
            velSamples.Add(velocity);
            timeSamples.Add(Time.time);

            // Detect reach start
            if (!movementStarted && velocity.magnitude >= velocityThreshold)
            {
                if (distanceFromStart >= 0.03f)
                {
                    startPos = currentPos;
                    startTime = Time.time;
                    movementStarted = true;
                    invalidAttempt = false;
                }
                else
                {
                    invalidAttempt = true;
                }
            }

            if (invalidAttempt && velocity.magnitude < velocityThreshold)
            {
                onFinish("Invalid Start");
                yield break;
            }

            if (movementStarted && velocity.magnitude < velocityThreshold)
            {
                endPos = currentPos;
                endTime = Time.time;

                string result = rewardEvaluator.Evaluate(endPos, shownTarget, penaltyBounds);
                dataLogger.LogTrialDetails(
                    trialNumber + 1,
                    conditionID,
                    shownTarget, penaltyCenter,
                    startCircleVisual.transform.position, startCircleVisual.transform.localScale,
                    startControllerPos,
                    startPos, endPos,
                    startTime, endTime,
                    GameManager.Instance.Points,
                    result,
                    targetSeed + trialNumber,
                    targetRandomSnapshot,
                    usedSeedPenalty,
                    penaltyRandomSnapshot,
                    timeSamples,
                    posSamples,
                    velSamples
                );

                onFinish(result);
                pointEvaluated = true;
            }

            if (!movementStarted && elapsed >= timeout)
            {
                onFinish("Too Slow");
                yield break;
            }

            if (movementStarted && elapsed >= timeout)
            {
                onFinish("Too Slow");
                yield break;
            }

            yield return null;
        }
    }
}
