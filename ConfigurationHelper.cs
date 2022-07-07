using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Configuration;

namespace MatlabReader
{
    public static class ConfigurationHelper
    {
        /// <summary>
        /// 
        /// </summary>
        /// <param name="key"></param>
        /// <returns></returns>
        public static string GetAppKeyValue(string key)
        {
            string value = ConfigurationManager.AppSettings[key];
            return value;
        }
    }
}
