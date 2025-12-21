using System.IO;
using System.Text;
using UnityEngine;
using System.Collections.Generic;

public class MovementLogger : MonoBehaviour
{
    private string filePathTrial;
    private string filePathSamples;
    public string participantInitials = "P01"; // Set in Inspector before running

    private const int ColumnWidth = 15; // Adjusted for clean alignment (not strictly used now, but kept)

    void Start()
    {
        string timestamp = System.DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss");
        string baseName = $"{participantInitials}_{timestamp}";

        filePathTrial = Path.Combine(Application.persistentDataPath, $"{baseName}_reaching_data.tsv");
        filePathSamples = Path.Combine(Application.persistentDataPath, $"{baseName}_position_velocity_log.tsv");

        // Add session header info
        string sessionHeader = $"Participant: {participantInitials}\nSession Start: {System.DateTime.Now}\n";
        File.WriteAllText(filePathTrial, sessionHeader);

        // Write column headers (now includes TargetIndex & PenaltyIndex)
        string trialHeader = WriteRow(
            "Trial", "ConditionID", "TargetIndex", "PenaltyIndex",
            "TargetX", "TargetY", "TargetZ",
            "PenaltyX", "PenaltyY", "PenaltyZ",
            "StartX", "StartY", "StartZ",
            "ScaleX", "ScaleY", "ScaleZ",
            "CtrlStartX", "CtrlStartY", "CtrlStartZ",
            "MoveStartX", "MoveStartY", "MoveStartZ",
            "EndX", "EndY", "EndZ",
            "StartTime", "EndTime", "Score",
            "Result", "TargetSeed",
            "TargetFirstX", "TargetFirstY", "TargetFirstZ",
            "TargetLastX", "TargetLastY", "TargetLastZ",
            "PenaltySeed",
            "PenaltyFirstX", "PenaltyFirstY", "PenaltyFirstZ",
            "PenaltyLastX", "PenaltyLastY", "PenaltyLastZ"
        );
        File.AppendAllText(filePathTrial, trialHeader + "\n");

        // Sample log header
        File.WriteAllText(filePathSamples, sessionHeader);
        string sampleHeader = WriteRow("Trial", "Time", "PosX", "PosY", "PosZ", "VelX", "VelY", "VelZ", "Speed");
        File.AppendAllText(filePathSamples, sampleHeader + "\n");

        Debug.Log($"[Logger] Logging to: {filePathTrial}");
    }

    public void LogTrialDetails(
        int trial,
        int conditionID,
        Vector3 targetPos,
        Vector3 penaltyPos,
        Vector3 startCirclePosition,
        Vector3 startCircleScale,
        Vector3 controllerStartPos,
        Vector3 movementStartPos,
        Vector3 movementEndPos,
        float startTime,
        float endTime,
        int scoreAfterTrial,
        string result,
        int usedSeedTarget,
        List<Vector3> targetRandomSnapshot,
        int usedSeedPenalty,
        List<Vector3> penaltyRandomSnapshot,
        List<float> times,
        List<Vector3> positions,
        List<Vector3> velocities,
        int targetIndex = -1,      // optional (for target-only or explicit pass)
        int penaltyIndex = -1      // optional (-1 can mean "no penalty")
    )
    {
        // If caller didn’t explicitly pass targetIndex / penaltyIndex,
        // infer them from conditionID using your encoding (T*10 + P).
        if (targetIndex < 0 || penaltyIndex < 0)
        {
            targetIndex = conditionID / 10;
            penaltyIndex = conditionID % 10;
        }

        Vector3 targetFirstDot = targetRandomSnapshot.Count > 0 ? targetRandomSnapshot[0] : Vector3.zero;
        Vector3 targetLastDot = targetRandomSnapshot.Count > 1 ? targetRandomSnapshot[^1] : Vector3.zero;

        Vector3 penaltyFirstDot = penaltyRandomSnapshot.Count > 0 ? penaltyRandomSnapshot[0] : Vector3.zero;
        Vector3 penaltyLastDot = penaltyRandomSnapshot.Count > 1 ? penaltyRandomSnapshot[^1] : Vector3.zero;

        string summary = WriteRow(
            trial, conditionID, targetIndex, penaltyIndex,
            targetPos.x, targetPos.y, targetPos.z,
            penaltyPos.x, penaltyPos.y, penaltyPos.z,
            startCirclePosition.x, startCirclePosition.y, startCirclePosition.z,
            startCircleScale.x, startCircleScale.y, startCircleScale.z,
            controllerStartPos.x, controllerStartPos.y, controllerStartPos.z,
            movementStartPos.x, movementStartPos.y, movementStartPos.z,
            movementEndPos.x, movementEndPos.y, movementEndPos.z,
            startTime, endTime, scoreAfterTrial,
            result.Trim(),
            usedSeedTarget,
            targetFirstDot.x, targetFirstDot.y, targetFirstDot.z,
            targetLastDot.x, targetLastDot.y, targetLastDot.z,
            usedSeedPenalty,
            penaltyFirstDot.x, penaltyFirstDot.y, penaltyFirstDot.z,
            penaltyLastDot.x, penaltyLastDot.y, penaltyLastDot.z
        );
        File.AppendAllText(filePathTrial, summary + "\n");

        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < times.Count; i++)
        {
            Vector3 pos = positions[i];
            Vector3 vel = velocities[i];
            float speed = vel.magnitude;
            sb.AppendLine(WriteRow(trial, times[i], pos.x, pos.y, pos.z, vel.x, vel.y, vel.z, speed));
        }
        File.AppendAllText(filePathSamples, sb.ToString());

        Debug.Log($"[Logger] Trial {trial} saved. TargetSeed={usedSeedTarget}, PenaltySeed={usedSeedPenalty}, ConditionID={conditionID}, TargetIndex={targetIndex}, PenaltyIndex={penaltyIndex}");
    }

    private string WriteRow(params object[] values)
    {
        StringBuilder row = new StringBuilder();
        for (int i = 0; i < values.Length; i++)
        {
            string formattedVal = values[i] switch
            {
                float f => f.ToString("G9"), // full float precision
                double d => d.ToString("G9"),
                _ => values[i].ToString()
            };

            row.Append(formattedVal);
            if (i < values.Length - 1)
                row.Append('\t');
        }
        return row.ToString();
    }
}
