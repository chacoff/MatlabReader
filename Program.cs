using System;
using System.IO;
using System.Collections.Generic;
using System.Configuration;
using System.Diagnostics;
using System.Text;

namespace MatlabReader
{
    class Program
    {
        public static string mfiles = $"cd {ConfigurationHelper.GetAppKeyValue("mfiles")}";
        public static string func = ConfigurationHelper.GetAppKeyValue("func");

        static void Main(string[] args)
        {

            // Create the MATLAB instance 
            MLApp.MLApp matlab = new MLApp.MLApp();

            // Change to the directory where the function is located 
            matlab.Execute(mfiles);

            // Define the output 
            object result = null;

            // Call the MATLAB function myfunc
            var arg1 = "config.txt";
            var arg2 = "21.txt,22.txt,23.txt";
            matlab.Feval(func, 1, out result, arg1, arg2); // 1 is the number of outputs of the matlab function

            // Display result 
            object[] res = result as object[];

            Console.WriteLine(res[0]);

            // Get user input to terminate program
            // Console.ReadLine();
        }
    }
}