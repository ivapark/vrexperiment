using System.IO;
using UnityEngine;

public class MovementLogger : MonoBehaviour
{
    private string filePath;

    void Start()
    {
        filePath = Application.persistentDataPath + "/reaching_data.csv";
        File.WriteAllText(filePath, "Trial,StartX,StartY,StartZ,EndX,EndY,EndZ,StartTime,EndTime,Vx,Vy,Vz\n");
    }

    public void LogTrial(int trial, Vector3 start, Vector3 end, float tStart, float tEnd, Vector3 velocity)
    {
        string line = $"{trial},{start.x},{start.y},{start.z},{end.x},{end.y},{end.z},{tStart},{tEnd},{velocity.x},{velocity.y},{velocity.z}\n";
        File.AppendAllText(filePath, line);
        Debug.Log("Trial data saved: " + line);
    }
}