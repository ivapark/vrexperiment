using UnityEngine;
using TMPro;
using System.Collections;
using System.Text;
using System.Collections.Generic;

public class FeedbackDisplay : MonoBehaviour
{
    public TextMeshPro textMesh3D;
    public LeaderboardManager leaderboardManager; // assign in Inspector

    public void ShowMessage(string msg, Color _ignoredColor, Vector3 worldPosition)
    {
        if (textMesh3D == null) return;

        textMesh3D.text = msg;
        textMesh3D.color = Color.black;

        if (textMesh3D.fontMaterial.HasProperty("_FaceColor"))
            textMesh3D.fontMaterial.SetColor("_FaceColor", Color.black);

        textMesh3D.transform.position = worldPosition;

        var cam = Camera.main;
        if (cam != null)
        {
            Vector3 toCam = cam.transform.position - textMesh3D.transform.position;
            textMesh3D.transform.rotation = Quaternion.LookRotation(toCam) * Quaternion.Euler(0f, 180f, 0f);
        }

        textMesh3D.gameObject.SetActive(true);

        CancelInvoke(nameof(HideMessage));
        Invoke(nameof(HideMessage), 0.8f);
    }

    public void ShowMessage2(string msg, Color _ignoredColor, Vector3 worldPosition)
    {
        if (textMesh3D == null) return;

        textMesh3D.text = msg;
        textMesh3D.color = Color.black;

        if (textMesh3D.fontMaterial.HasProperty("_FaceColor"))
            textMesh3D.fontMaterial.SetColor("_FaceColor", Color.black);

        textMesh3D.transform.position = worldPosition;

        var cam = Camera.main;
        if (cam != null)
        {
            Vector3 toCam = cam.transform.position - textMesh3D.transform.position;
            textMesh3D.transform.rotation = Quaternion.LookRotation(toCam) * Quaternion.Euler(0f, 180f, 0f);
        }

        textMesh3D.gameObject.SetActive(true);

        CancelInvoke(nameof(HideMessage));
        Invoke(nameof(HideMessage), 10f);
    }

    public void ShowCountdownMessage(int seconds, int currentScore, int blockNumber, Vector3 worldPosition)
    {
        if (textMesh3D == null) return;

        StopAllCoroutines();
        StartCoroutine(CountdownRoutine(seconds, currentScore, blockNumber, worldPosition));
    }

    private IEnumerator CountdownRoutine(int seconds, int currentScore, int blockNumber, Vector3 worldPosition)
    {
        int timeLeft = seconds;

        while (timeLeft > 0)
        {
            string leaderboardText = BuildLeaderboardTextForBlock(blockNumber);
            UpdateMessage(
                $"Take a short break!\nNext trial starts in {timeLeft} seconds.\n\n" +
                $"Your Score: {currentScore}\n\n{leaderboardText}",
                worldPosition
            );

            yield return new WaitForSeconds(1f);
            timeLeft--;
        }

        UpdateMessage("Starting next trial!", worldPosition);
        yield return new WaitForSeconds(1f);
        HideMessage();
    }

    private string BuildLeaderboardTextForBlock(int blockNumber)
    {
        if (leaderboardManager == null)
            return "Leaderboard unavailable.";

        var list = leaderboardManager.GetLeaderboardForBlock(blockNumber);
        if (list == null || list.Count == 0)
            return $"No leaderboard data yet for {blockNumber} trials.";

        StringBuilder sb = new StringBuilder();
        sb.AppendLine($"<b> Leaderboard — After {blockNumber} Trials</b>");
        for (int i = 0; i < list.Count; i++)
            sb.AppendLine($"{i + 1}. {list[i].playerName} - {list[i].score}");
        return sb.ToString();
    }

    private void UpdateMessage(string msg, Vector3 worldPosition)
    {
        textMesh3D.text = msg;
        textMesh3D.color = Color.black;

        if (textMesh3D.fontMaterial.HasProperty("_FaceColor"))
            textMesh3D.fontMaterial.SetColor("_FaceColor", Color.black);

        textMesh3D.transform.position = worldPosition;

        var cam = Camera.main;
        if (cam != null)
        {
            Vector3 toCam = cam.transform.position - textMesh3D.transform.position;
            textMesh3D.transform.rotation = Quaternion.LookRotation(toCam) * Quaternion.Euler(0f, 180f, 0f);
        }

        textMesh3D.gameObject.SetActive(true);
    }

    public void HideMessage()
    {
        if (textMesh3D != null)
            textMesh3D.gameObject.SetActive(false);
    }
}
