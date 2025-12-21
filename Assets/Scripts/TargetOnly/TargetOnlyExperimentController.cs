using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR;

public class TargetOnlyExperimentController : MonoBehaviour
{
    public Transform rightHandController;
    public MovementLogger dataLogger;
    public TargetOnlyTargetController targetController;

    public RewardEvaluator rewardEvaluator;
    public FeedbackDisplay feedbackDisplay;
    public GameObject startCircleVisual;
    public StartZoneDetector startZoneDetector;

    [Header("Materials")]
    public Material targetPrepMaterial;
    public Material targetGoMaterial;
    public Material hitMaterial;
    public Material missMaterial;
    public Material neutralMaterial;
    public Material tooSlowMaterial;

    [Header("Audio")]
    public AudioSource audioSource;
    public AudioClip hitClip;
    public AudioClip missClip;
    public AudioClip errorClip;   // invalid, too early, too slow

    public LeaderboardManager leaderboardManager;
    public string playerName = "Player"; // optional, for future use

    [Header("Experiment Settings")]
    public int totalTrials = 10;

    private InputDevice rightHandDevice;
    private int targetSeed;

    private List<Vector3> targetRandomSnapshot;

    // block
    private int scoreAtStartOfBlock = 0;

    void Start()
    {
        targetSeed = System.DateTime.Now.GetHashCode();
        Debug.Log($"[TargetOnlyExperimentController] Using Target Seed: {targetSeed}");

        scoreAtStartOfBlock = GameManager.Instance.Points;

        rightHandDevice = InputDevices.GetDeviceAtXRNode(XRNode.RightHand);
        StartCoroutine(DelayThenRun());
    }

    IEnumerator DelayThenRun()
    {
        while (targetController == null || targetController.targets == null || targetController.targets.Count < 9)
            yield return null;

        StartCoroutine(RunTrials());
    }

    IEnumerator RunTrials()
    {
        int trialCount = 0;

        while (true)
        {
            TargetOnlyCondition condition = TargetOnlyTrialManager.Instance.GetNextTrial();
            if (condition == null)
            {
                Debug.Log("All trials complete.");
                ShowFinalScore();
                yield break;
            }

            // For target-only, ConditionID can just be the target index (0..8)
            int conditionID = condition.targetIndex;
            int targetIndex = condition.targetIndex;

            trialCount++;
            Debug.Log($"[TargetOnly] Starting Trial {trialCount}/{TargetOnlyTrialManager.Instance.TotalTrialCount}");

            // --- Scheduled Break Every 10 Trials ---
            if (trialCount > 1 && (trialCount - 1) % 10 == 0)
            {
                int currentScore = GameManager.Instance.Points;
                int currentBlock = trialCount; // 10, 20, 30...
                Vector3 breakPosition = Camera.main.transform.position + Camera.main.transform.forward * 0.3f;

                // Add leaderboard entry for this block
                LeaderboardManager leaderboard = FindObjectOfType<LeaderboardManager>();
                if (leaderboard != null)
                {
                    string initials = dataLogger != null ? dataLogger.participantInitials : "Player";
                    leaderboard.AddEntryForBlock(initials, currentBlock, currentScore);
                }

                // Prepare for next block
                scoreAtStartOfBlock = GameManager.Instance.Points;

                // Show the countdown for 10 seconds
                feedbackDisplay.leaderboardManager = leaderboard;
                feedbackDisplay.ShowCountdownMessage(10, currentScore, currentBlock, breakPosition);

                // Wait until countdown is done before continuing
                yield return new WaitForSeconds(11f); // 10 for countdown + 1 for transition
            }

            // --- Wait for hand to enter start zone ---
            yield return StartCoroutine(WaitForHandToEnterStartZone());

            // --- Target setup ---
            GameObject target = targetController.GetTarget(targetIndex);
            Random.InitState(targetSeed + trialCount);
            targetController.GenerateDotsForTarget(targetIndex);
            targetController.ActivateOnly(targetIndex);

            targetRandomSnapshot = new List<Vector3>();
            if (targetController.targetRandomValues.Count > 0)
            {
                targetRandomSnapshot.Add(targetController.targetRandomValues[0]);
                targetRandomSnapshot.Add(targetController.targetRandomValues[^1]);
            }

            targetController.SetMaterial(targetPrepMaterial);

            // --- Wait for stable start (Ready - Go) ---
            string outcome = "Too Slow";
            bool earlyExit = false;
            yield return StartCoroutine(WaitForStableHandInStartZone((earlyResult) =>
            {
                outcome = earlyResult;
                earlyExit = true;
            }));

            // Handle Too Early case
            if (earlyExit && outcome == "Too Early")
            {
                LogPlaceholder(trialCount, conditionID, targetIndex, target, "Too Early");
                SetFeedback("Too Early", target);
                startCircleVisual.SetActive(false);

                yield return new WaitForSeconds(1.5f);
                targetController.DeactivateAll();
                TargetOnlyTrialManager.Instance.ReinsertTrial(condition);
                yield return new WaitForSeconds(1.0f);
                continue;
            }

            // --- Capture movement ---
            yield return StartCoroutine(
                CaptureMovement(
                    target,
                    trialCount - 1,
                    conditionID,
                    targetIndex,
                    0.05f,
                    2.0f,
                    (result) => outcome = result
                )
            );

            // Reinsertion logic for invalid/slow trials
            if (outcome == "Too Slow" || outcome == "Invalid Start")
            {
                LogPlaceholder(trialCount, conditionID, targetIndex, target, outcome);
                TargetOnlyTrialManager.Instance.ReinsertTrial(condition);
            }

            // --- Feedback + cleanup ---
            SetFeedback(outcome, target);
            yield return new WaitForSeconds(1.5f);
            targetController.DeactivateAll();
        }
    }

    private void SetFeedback(string outcome, GameObject target)
    {
        Color feedbackColor = outcome switch
        {
            "Hit" => Color.green,
            "Neutral" => Color.white,
            "Invalid Start" or "Too Early" => Color.gray,
            "Missed" => Color.red,
            _ => Color.gray
        };

        string message = outcome switch
        {
            "Hit" => "Hit! +300",
            "Neutral" => "Didn't hit! +0",
            "Missed" => "Missed! -500",
            "Invalid Start" => "Invalid Start!",
            "Too Early" => "Too Early!",
            _ => "Too Slow!"
        };

        // --- AUDIO FEEDBACK (same pattern as other experiments) ---
        if (audioSource != null)
        {
            switch (outcome)
            {
                case "Hit":
                    audioSource.PlayOneShot(hitClip);
                    break;

                case "Missed":
                    audioSource.PlayOneShot(missClip);
                    break;

                case "Invalid Start":
                case "Too Early":
                case "Too Slow":
                    audioSource.PlayOneShot(errorClip);
                    break;

                default:
                    // Neutral = no sound
                    break;
            }
        }

        targetController.SetFeedbackMaterial(outcome, hitMaterial, missMaterial, neutralMaterial, tooSlowMaterial);
        Vector3 forward = Camera.main.transform.forward;
        Vector3 feedbackPosition = Camera.main.transform.position + forward * 0.2f;
        feedbackDisplay.ShowMessage(message, feedbackColor, feedbackPosition);
    }

    private void LogPlaceholder(int trialCount, int conditionID, int targetIndex, GameObject target, string result)
    {
        // PenaltyIndex = 0, no penalty position/seed
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
            -1,
            new List<Vector3>(),
            new List<float>(),
            new List<Vector3>(),
            new List<Vector3>(),
            targetIndex,
            0                // PenaltyIndex (none)
        );
    }

    private void ShowFinalScore()
    {
        int finalScore = GameManager.Instance.Points;
        int maxScore = totalTrials * 300;
        string finalMessage = $"All trials complete!\nTotal Score: {finalScore} / {maxScore}";
        feedbackDisplay.ShowMessage2(finalMessage, Color.yellow, Camera.main.transform.position + Camera.main.transform.forward * 0.3f);
        Debug.Log($"[TargetOnly Feedback] Final Score: {finalScore}");

        string initials = dataLogger.participantInitials;
        if (string.IsNullOrEmpty(initials))
            initials = "N/A";
        if (leaderboardManager != null)
        {
            var finalList = leaderboardManager.GetFinalLeaderboard();
            // you can display this if you want, like in LR/TB/FB
        }
    }

    IEnumerator WaitForHandToEnterStartZone()
    {
        startZoneDetector.handIsInZone = false;
        startCircleVisual.SetActive(true);
        while (!startZoneDetector.handIsInZone)
            yield return null;

        targetController.SetMaterial(targetPrepMaterial);
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

    IEnumerator CaptureMovement(
        GameObject target,
        int trialNumber,
        int conditionID,
        int targetIndex,
        float velocityThreshold,
        float timeout,
        System.Action<string> onFinish
    )
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

                // No penalty bounds in target-only version
                string result = rewardEvaluator.Evaluate(endPos, shownTarget, new Bounds());
                dataLogger.LogTrialDetails(
                    trialNumber + 1,
                    conditionID,
                    shownTarget,
                    Vector3.zero,
                    startCircleVisual.transform.position,
                    startCircleVisual.transform.localScale,
                    startControllerPos,
                    startPos, endPos,
                    startTime, endTime,
                    GameManager.Instance.Points,
                    result,
                    targetSeed + trialNumber,
                    targetRandomSnapshot,
                    -1,
                    new List<Vector3>(),
                    timeSamples,
                    posSamples,
                    velSamples,
                    targetIndex,
                    0              // PenaltyIndex (none)
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
