using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using UnityEngine;

public class CSVReader : Singleton<CSVReader>
{
	[SerializeField]
	private TextAsset csvFile;

	public Dictionary<string, string> LoadData(int currentLanguageID)
	{
		Dictionary<string, string> dictionary = new Dictionary<string, string>();
		string[] array = csvFile.text.Split(new string[2] { "\r\n", "\n" }, StringSplitOptions.RemoveEmptyEntries);
		foreach (string input in array)
		{
			string[] array2 = (from Match m in new Regex("(?<=^|,)(\"(?:[^\"]|\"\")*\"|[^,]*)").Matches(input)
				select m.Value).ToArray();
			int num = Enum.GetNames(typeof(Languages)).Length;
			if (array2.Length <= currentLanguageID || array2.Length != num + 1)
			{
				Debug.LogError("parsing failure, more content than number of languages");
			}
			else if (array2[0] != "")
			{
				if (!dictionary.ContainsKey(array2[0]))
				{
					string value = array2[currentLanguageID].Trim('"');
					dictionary.Add(array2[0].ToLower(), value);
				}
				else
				{
					Debug.LogError(array2[0] + " ID in Localization already exists before");
				}
			}
		}
		return dictionary;
	}
}
