using System;
using System.IO;
using System.Diagnostics;


namespace cmdMatlab
{
    public static class Program
    {

        public static string configfolder = ConfigurationHelper.GetAppKeyValue("configfolder");
        public static string dataFolder = ConfigurationHelper.GetAppKeyValue("dataFolder");
        public static string exe = ConfigurationHelper.GetAppKeyValue("exe");
        public static DateTime today = DateTime.Now;
        public static string folderToday = $"{dataFolder}{today.Year}_{today.Month.ToString("00")}_{today.Day.ToString("00")}\\";
        public static DirectoryInfo dinfo = new DirectoryInfo(folderToday);

        static void Main(string[] args)
        {
            FileInfo[] Files = dinfo.GetFiles("*.txt").ToArray();

            var data = string.Join(",", Files.Select(x => x.ToString()).ToArray());
            //string data = $"{folderToday}21.txt,{folderToday}22.txt,{folderToday}23.txt";

            Process process = new Process();
            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.WindowStyle = ProcessWindowStyle.Hidden; // Hidden,Normal
            startInfo.FileName = $"{exe}";

            startInfo.Arguments = $"{configfolder} {data}";
            
            process.StartInfo = startInfo;
            process.Start();
        }
    }
}
