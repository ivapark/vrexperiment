using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR;

public class FBExperimentController : MonoBehaviour
{
    public Transform rightHandController;
    public MovementLogger dataLogger;
    public TargetController targetController;
    public FBPenaltyController PenaltyController;

    public RewardEvaluator rewardEvaluator;
    public FeedbackDisplay feedbackDisplay;
    public GameObject startCircleVisual;
    public StartZoneDetector startZoneDetector;

    [Header("Materials")]
    public Material targetPrepMaterial;
    public Material penaltyPreorangeMaterial;
    public Material targetGoMaterial;
    public Material penaltyGoMaterial;
    public Material hitMaterial;
    public Material missMaterial;
    public Material neutralMaterial;
    public Material tooSlowMaterial;

    [Header("Audio")]
    public AudioSource audioSource;
    public AudioClip hitClip;
    public AudioClip missClip;
    public AudioClip errorClip; // invalid, too early, too slow

    public LeaderboardManager leaderboardManager;
    public string playerName = "Player"; // set this dynamically later

    [Header("Experiment Settings")]
    public int totalTrials = 10;

    private InputDevice rightHandDevice;
    private int targetSeed;
    private int usedSeedPenalty;

    private List<Vector3> targetRandomSnapshot;
    private List<Vector3> penaltyRandomSnapshot;

    // block
    private int scoreAtStartOfBlock = 0;

    void Start()
    {
        targetSeed = System.DateTime.Now.GetHashCode();
        Debug.Log($"[FBExperimentController] Using Target Seed: {targetSeed}");
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
            FBTrialCondition27 condition = FBTrialManager27.Instance.GetNextTrial();
            if (condition == null)
            {
                Debug.Log("All trials complete.");
                ShowFinalScore();
                // could also StartCoroutine(DisplayLeaderboard());
                yield break;
            }

            // Use the condition's own index as ConditionID (0..26)
            int conditionID = condition.conditionIndex;

            trialCount++;
            Debug.Log($"[FB] Starting Trial {trialCount}/{FBTrialManager27.Instance.TotalTrialCount}");

            // --- Wait for hand to enter start zone ---
            yield return StartCoroutine(WaitForHandToEnterStartZone());

            // --- Prepare and activate target ---
            GameObject target = targetController.GetTarget(condition.targetIndex);
            Random.InitState(targetSeed + trialCount);
            targetController.GenerateDotsForTarget(condition.targetIndex);
            targetController.ActivateOnly(condition.targetIndex);

            // Snapshot of target random positions
            targetRandomSnapshot = new List<Vector3>();
            if (targetController.targetRandomValues.Count > 0)
            {
                targetRandomSnapshot.Add(targetController.targetRandomValues[0]);
                targetRandomSnapshot.Add(targetController.targetRandomValues[^1]);
            }

            // --- Penalty setup ---
            bool hasPenalty = condition.penaltyIndex != 0;
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
                penaltyRandomSnapshot = new List<Vector3>();
            }

            targetController.SetMaterial(targetPrepMaterial);
            if (hasPenalty) PenaltyController.SetMaterial(penaltyPreorangeMaterial);

            // --- Wait for stable hand (Ready - Go) ---
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
                LogPlaceholder(trialCount, conditionID, condition.targetIndex, condition.penaltyIndex, target, "Too Early");
                SetFeedback("Too Early", target, hasPenalty);
                startCircleVisual.SetActive(false);

                yield return new WaitForSeconds(1.5f);
                targetController.DeactivateAll();
                if (hasPenalty) PenaltyController.ClearPenalty();

                FBTrialManager27.Instance.ReinsertTrial(condition);
                yield return new WaitForSeconds(0.0f);
                continue;
            }

            // --- Capture movement ---
            yield return StartCoroutine(
                CaptureMovement(
                    target,
                    trialCount - 1,
                    conditionID,
                    condition.targetIndex,
                    condition.penaltyIndex,
                    0.05f,
                    2.0f,
                    (result) => outcome = result
                )
            );

            // Reinsertion logic for invalid/slow trials
            if (outcome == "Too Slow" || outcome == "Invalid Start")
            {
                LogPlaceholder(trialCount, conditionID, condition.targetIndex, condition.penaltyIndex, target, outcome);
                FBTrialManager27.Instance.ReinsertTrial(condition);
            }

            // --- Feedback and cleanup ---
            SetFeedback(outcome, target, hasPenalty);
            yield return new WaitForSeconds(1.5f);

            targetController.DeactivateAll();
            if (hasPenalty) PenaltyController.ClearPenalty();

            // --- BLOCK SAVE (after trial finishes) ---
            if (trialCount % 10 == 0)
            {
                int currentBlock = trialCount;  // block 10, 20, 30…
                int blockScore = GameManager.Instance.Points;

                LeaderboardManager leaderboard = FindObjectOfType<LeaderboardManager>();
                if (leaderboard != null)
                {
                    string initials = dataLogger != null ? dataLogger.participantInitials : "Player";
                    leaderboard.AddEntryForBlock(initials, currentBlock, blockScore);
                }

                // Prepare for the next block
                scoreAtStartOfBlock = GameManager.Instance.Points;

                // Show UI
                Vector3 breakPosition = Camera.main.transform.position + Camera.main.transform.forward * 0.3f;
                feedbackDisplay.leaderboardManager = leaderboard;
                feedbackDisplay.ShowCountdownMessage(10, GameManager.Instance.Points, currentBlock, breakPosition);

                yield return new WaitForSeconds(11f);
            }
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

        // --- AUDIO FEEDBACK ---
        if (audioSource != null)
        {
            switch (outcome)
            {
                case "Hit":
                    audioSource.PlayOneShot(hitClip);
                    break;

                case "Missed":
                case "Hit Both":
                    audioSource.PlayOneShot(missClip);
                    break;

                case "Invalid Start":
                case "Too Early":
                case "Too Slow":
                    audioSource.PlayOneShot(errorClip);
                    break;

                default:
                    // neutral = no sound
                    break;
            }
        }

        targetController.SetFeedbackMaterial(outcome, hitMaterial, missMaterial, neutralMaterial, tooSlowMaterial);
        if (hasPenalty)
            PenaltyController.SetFeedbackMaterial(outcome, hitMaterial, missMaterial, neutralMaterial, tooSlowMaterial);

        Vector3 forward = Camera.main.transform.forward;
        Vector3 feedbackPosition = Camera.main.transform.position + forward * 0.2f;
        feedbackDisplay.ShowMessage(message, feedbackColor, feedbackPosition);
    }

    private void LogPlaceholder(int trialCount, int conditionID, int targetIndex, int penaltyIndex, GameObject target, string result)
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
            new List<Vector3>(),
            targetIndex,
            penaltyIndex
        );
    }

    private void ShowFinalScore()
    {
        int finalScore = GameManager.Instance.Points;
        int maxScore = totalTrials * 300;
        string finalMessage = $"All trials complete!\nTotal Score: {finalScore} / {maxScore}";
        feedbackDisplay.ShowMessage2(finalMessage, Color.yellow, Camera.main.transform.position + Camera.main.transform.forward * 0.3f);
        Debug.Log($"[FB Feedback] Final Score: {finalScore}");

        string initials = dataLogger.participantInitials;
        if (string.IsNullOrEmpty(initials))
            initials = "N/A";
        var finalList = leaderboardManager.GetFinalLeaderboard();
    }

    private IEnumerator DisplayLeaderboard()
    {
        string leaderboardText = " Top 5 Leaderboard \n\n";
        int rank = 1;
        foreach (var entry in leaderboardManager.entries)
        {
            leaderboardText += $"{rank}. {entry.playerName} — {entry.score}\n";
            rank++;
        }

        feedbackDisplay.ShowMessage2(leaderboardText, Color.cyan, Camera.main.transform.position + Camera.main.transform.forward * 0.4f);
        yield return new WaitForSeconds(5f);
        Debug.Log(leaderboardText);
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

    IEnumerator CaptureMovement(
        GameObject target,
        int trialNumber,
        int conditionID,
        int targetIndex,
        int penaltyIndex,
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

        bool movementStarted = false;
        bool pointEvaluated = false;
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
                else invalidAttempt = true;
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
                    velSamples,
                    targetIndex,
                    penaltyIndex
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
