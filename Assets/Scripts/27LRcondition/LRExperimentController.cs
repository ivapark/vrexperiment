using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR;

public class LRExperimentController : MonoBehaviour
{
    public Transform rightHandController;
    public MovementLogger dataLogger;
    public TargetController targetController;
    public PenaltyControllerLR PenaltyController;


    public RewardEvaluator rewardEvaluator;
    public FeedbackDisplay feedbackDisplay;
    public GameObject startCircleVisual;
    public StartZoneDetector startZoneDetector;

    [Header("UI Anchors")]
    public Transform feedbackAnchor;  // assign in Inspector

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

    [Header("Debug / Visualization")]
    public GameObject endpointMarkerPrefab;
    private GameObject endpointMarkerInstance;

    // ========================
    // Kinematic thresholds
    // ========================
    [Header("Kinematic Thresholds")]
    public float startVelocityThreshold = 0.08f;   // used for reach start + "Too Early"
    public float endVelocityThreshold = 0.02f;     // used for end-of-movement
    public float accelEndThreshold = 1.0f;         // how "flat" accel must be to end
    public float endStableDuration = 0.08f;        // seconds velocity+accel must stay small
    public float minStartDistance = 0.03f;         // distance from start to count as real reach
    public float movementTimeout = 1.3f;           // time limit per reach

    // ========================
    // Endpoint: NO correction
    // ========================
    [Header("Endpoint (No-Correction / Progress)")]
    public float backtrackTolerance = 0.01f;       // meters: how much progress drop counts as "going back"
    public float backtrackDuration = 0.03f;        // seconds: how long must it go back to end early
    public float minProgressForEndpoint = 0.05f;   // meters: don't end from tiny jitters early
    // ========================

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
        Debug.Log($"[LRExperimentController] Using Target Seed: {targetSeed}");
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
            TrialCondition27 condition = TrialManager27.Instance.GetNextTrial();
            if (condition == null)
            {
                Debug.Log("All trials complete.");
                ShowFinalScore();
                yield break;
            }

            int conditionID = condition.conditionIndex;

            trialCount++;
            Debug.Log($"Starting Trial {trialCount}/{TrialManager27.Instance.TotalTrialCount}");

            // --- Wait for hand to enter start zone ---
            yield return StartCoroutine(WaitForHandToEnterStartZone());

            // --- Prepare and activate target ---
            GameObject target = targetController.GetTarget(condition.targetIndex);
            Random.InitState(targetSeed + trialCount);
            targetController.GenerateDotsForTarget(condition.targetIndex);
            targetController.ActivateOnly(condition.targetIndex);

            // Snapshot of target random positions (for logging)
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

            // --- Wait for stable start (Ready - Go) ---
            string outcome = "Too Slow";
            bool earlyExit = false;

            yield return StartCoroutine(WaitForStableHandInStartZone((earlyResult) =>
            {
                outcome = earlyResult;
                earlyExit = true;
            }));

            if (earlyExit && outcome == "Too Early")
            {
                LogPlaceholder(trialCount, conditionID, condition.targetIndex, condition.penaltyIndex, target, "Too Early");
                SetFeedback("Too Early", target, hasPenalty);

                startCircleVisual.SetActive(false);

                yield return new WaitForSeconds(1.5f);

                targetController.DeactivateAll();
                if (hasPenalty) PenaltyController.ClearPenalty();

                TrialManager27.Instance.ReinsertTrial(condition);
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
                    startVelocityThreshold,
                    endVelocityThreshold,
                    movementTimeout,
                    (result) => outcome = result
                )
            );

            if (outcome == "Too Slow" || outcome == "Invalid Start")
            {
                LogPlaceholder(trialCount, conditionID, condition.targetIndex, condition.penaltyIndex, target, outcome);
                TrialManager27.Instance.ReinsertTrial(condition);
            }

            // --- Feedback and cleanup ---
            SetFeedback(outcome, target, hasPenalty);
            yield return new WaitForSeconds(1.5f);

            HideEndpointMarker();

            targetController.DeactivateAll();
            if (hasPenalty) PenaltyController.ClearPenalty();

            // --- BLOCK SAVE (after trial finishes) ---
            if (trialCount % 10 == 0)
            {
                int currentBlock = trialCount;
                int blockScore = GameManager.Instance.Points;

                LeaderboardManager leaderboard = FindObjectOfType<LeaderboardManager>();
                if (leaderboard != null)
                {
                    string initials = dataLogger != null ? dataLogger.participantInitials : "Player";
                    leaderboard.AddEntryForBlock(initials, currentBlock, blockScore);
                }

                scoreAtStartOfBlock = GameManager.Instance.Points;

                Vector3 breakPosition = feedbackAnchor != null
                    ? feedbackAnchor.position
                    : Camera.main.transform.position + Camera.main.transform.forward * 0.3f;

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
            "Hit Target" => Color.green,
            "Hit Penalty" or "Hit Both" => Color.red,
            "Missed" => Color.white,
            "Invalid Start" or "Too Early" => Color.gray,
            _ => Color.gray
        };

        string message = outcome switch
        {
            "Hit Target" => "Hit Target! +300",
            "Hit Penalty" => "Hit Penalty! -500",
            "Hit Both" => "Hit Both! -200",
            "Missed" => "Missed! +0",
            "Invalid Start" => "Invalid Start!",
            "Too Early" => "Too Early!",
            _ => "Time's Up!"
        };

        if (audioSource != null)
        {
            switch (outcome)
            {
                case "Hit Target":
                    audioSource.PlayOneShot(hitClip);
                    break;

                case "Hit Penalty":
                case "Hit Both":
                    audioSource.PlayOneShot(missClip);
                    break;

                case "Invalid Start":
                case "Too Early":
                case "Too Slow":
                case "Missed":
                    audioSource.PlayOneShot(errorClip);
                    break;
            }
        }

        targetController.SetFeedbackMaterial(outcome, hitMaterial, missMaterial, neutralMaterial, tooSlowMaterial);
        if (hasPenalty)
            PenaltyController.SetFeedbackMaterial(outcome, hitMaterial, missMaterial, neutralMaterial, tooSlowMaterial);

        Vector3 feedbackPosition = feedbackAnchor != null
            ? feedbackAnchor.position
            : Camera.main.transform.position + Camera.main.transform.forward * 0.2f;

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
            targetSeed + trialCount,         // matches Random.InitState(targetSeed + trialCount)
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
        string finalMessage = $"All trials complete!\nTotal Score: {finalScore}";

        Vector3 pos = feedbackAnchor != null
            ? feedbackAnchor.position
            : Camera.main.transform.position + Camera.main.transform.forward * 0.3f;

        feedbackDisplay.ShowMessage2(finalMessage, Color.yellow, pos);
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

        float velocityThreshold = startVelocityThreshold;
        float requiredStillTime = 0.5f;

        while (true)
        {
            Vector3 currentPos = rightHandController.position;
            float dt = Time.deltaTime;
            if (dt <= 0f) dt = 0.001f;

            Vector3 velocity = (currentPos - prevPos) / dt;
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
                    stillTimer += dt;
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
        int trialNumber, // this is (trialCount - 1)
        int conditionID,
        int targetIndex,
        int penaltyIndex,
        float startVelocityThreshold,
        float endVelocityThreshold,
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

        // Acceleration + stability state
        Vector3 prevVel = Vector3.zero;
        bool hasPrevVel = false;
        float stableTimer = 0f;

        // ===== NEW: progress axis (start -> target) to avoid “correction” endpoint =====
        Vector3 reachVec = shownTarget - startControllerPos;
        Vector3 reachDir = (reachVec.sqrMagnitude > 1e-8f) ? reachVec.normalized : Vector3.forward;

        float maxProgress = float.NegativeInfinity;
        Vector3 maxProgressPos = startControllerPos;
        float backtrackTimer = 0f;
        bool progressInitialized = false;
        // ===========================================================================

        while (!pointEvaluated)
        {
            Vector3 currentPos = rightHandController.position;
            float dt = Time.deltaTime;
            if (dt <= 0f) dt = 0.001f;

            Vector3 velocity = (currentPos - prevPos) / dt;
            prevPos = currentPos;

            Vector3 acceleration = Vector3.zero;
            if (hasPrevVel)
                acceleration = (velocity - prevVel) / dt;

            prevVel = velocity;
            hasPrevVel = true;

            elapsed += dt;

            float distanceFromStart = Vector3.Distance(currentPos, startControllerPos);

            posSamples.Add(currentPos);
            velSamples.Add(velocity);
            timeSamples.Add(Time.time);

            // Detect reach start
            if (!movementStarted && velocity.magnitude >= startVelocityThreshold)
            {
                if (distanceFromStart >= minStartDistance)
                {
                    startPos = currentPos;
                    startTime = Time.time;
                    movementStarted = true;
                    invalidAttempt = false;

                    // init progress tracking at reach start
                    progressInitialized = true;
                    maxProgress = Vector3.Dot(currentPos - startControllerPos, reachDir);
                    maxProgressPos = currentPos;
                    backtrackTimer = 0f;
                    stableTimer = 0f;
                }
                else
                {
                    invalidAttempt = true;
                }
            }

            if (invalidAttempt && velocity.magnitude < startVelocityThreshold)
            {
                onFinish("Invalid Start");
                yield break;
            }

            if (movementStarted)
            {
                float speed = velocity.magnitude;
                float accelMag = acceleration.magnitude;

                // --- NEW: track furthest forward progress so endpoint is NOT the corrected point ---
                float progress = Vector3.Dot(currentPos - startControllerPos, reachDir);
                if (!progressInitialized)
                {
                    progressInitialized = true;
                    maxProgress = progress;
                    maxProgressPos = currentPos;
                }
                else if (progress > maxProgress)
                {
                    maxProgress = progress;
                    maxProgressPos = currentPos;
                }

                bool goingBack = progress < (maxProgress - backtrackTolerance);

                if (maxProgress > minProgressForEndpoint && goingBack)
                    backtrackTimer += dt;
                else
                    backtrackTimer = 0f;

                // If they clearly start moving back, end NOW at the furthest-forward point
                if (backtrackTimer >= backtrackDuration)
                {
                    endPos = maxProgressPos;     // <-- no correction endpoint
                    endTime = Time.time;

                    ShowEndpointMarker(endPos);

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
                        targetSeed + (trialNumber + 1), // matches Random.InitState(targetSeed + trialCount)
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
                    yield break;
                }

                // Existing stable end rule (but log maxProgressPos to avoid correction)
                if (speed < endVelocityThreshold && accelMag < accelEndThreshold)
                    stableTimer += dt;
                else
                    stableTimer = 0f;

                if (stableTimer >= endStableDuration)
                {
                    // IMPORTANT: use maxProgressPos here too (no correction)
                    endPos = maxProgressPos;
                    endTime = Time.time;

                    ShowEndpointMarker(endPos);

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
                        targetSeed + (trialNumber + 1),
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
                    yield break;
                }
            }

            // Timeout logic
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

    private void ShowEndpointMarker(Vector3 position)
    {
        if (endpointMarkerPrefab == null)
        {
            Debug.LogWarning("[LRExperimentController] No endpointMarkerPrefab assigned.");
            return;
        }

        if (endpointMarkerInstance == null)
        {
            endpointMarkerInstance = Instantiate(endpointMarkerPrefab, position, Quaternion.identity);
            endpointMarkerInstance.name = "EndpointMarker";
            endpointMarkerInstance.transform.localScale = Vector3.one * 0.01f;
        }
        else
        {
            endpointMarkerInstance.transform.position = position;
            endpointMarkerInstance.SetActive(true);
        }
    }

    private void HideEndpointMarker()
    {
        if (endpointMarkerInstance != null)
            endpointMarkerInstance.SetActive(false);
    }
}
