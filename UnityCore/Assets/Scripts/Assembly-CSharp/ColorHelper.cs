using UnityEngine;

public static class ColorHelper
{
	public static Color GetColorByHex(string hex)
	{
		string code = hex[0].ToString() + hex[1];
		string code2 = hex[2].ToString() + hex[3];
		string code3 = hex[4].ToString() + hex[5];
		float r = (float)GetRGBPerHex(code) / 255f;
		float g = (float)GetRGBPerHex(code2) / 255f;
		float b = (float)GetRGBPerHex(code3) / 255f;
		Debug.Log(r + " " + g + " " + b);
		return new Color(r, g, b);
	}

	private static int GetRGBPerHex(string code)
	{
		int num = 0;
		switch (code[0])
		{
		case '1':
			num += 16;
			break;
		case '2':
			num += 32;
			break;
		case '3':
			num += 48;
			break;
		case '4':
			num += 64;
			break;
		case '5':
			num += 80;
			break;
		case '6':
			num += 96;
			break;
		case '7':
			num += 112;
			break;
		case '8':
			num += 128;
			break;
		case '9':
			num += 144;
			break;
		case 'A':
			num += 160;
			break;
		case 'B':
			num += 176;
			break;
		case 'C':
			num += 192;
			break;
		case 'D':
			num += 208;
			break;
		case 'E':
			num += 224;
			break;
		case 'F':
			num += 240;
			break;
		}
		switch (code[0])
		{
		case '1':
			num++;
			break;
		case '2':
			num += 2;
			break;
		case '3':
			num += 3;
			break;
		case '4':
			num += 4;
			break;
		case '5':
			num += 5;
			break;
		case '6':
			num += 6;
			break;
		case '7':
			num += 7;
			break;
		case '8':
			num += 8;
			break;
		case '9':
			num += 9;
			break;
		case 'A':
			num += 10;
			break;
		case 'B':
			num += 11;
			break;
		case 'C':
			num += 12;
			break;
		case 'D':
			num += 13;
			break;
		case 'E':
			num += 14;
			break;
		case 'F':
			num += 15;
			break;
		}
		Debug.Log(num);
		return num;
	}

	public static string GetHexCode(Color color)
	{
		string hexPerColor = GetHexPerColor(Mathf.RoundToInt(color.r * 255f));
		string hexPerColor2 = GetHexPerColor(Mathf.RoundToInt(color.g * 255f));
		string hexPerColor3 = GetHexPerColor(Mathf.RoundToInt(color.b * 255f));
		return hexPerColor + hexPerColor2 + hexPerColor3;
	}

	private static string GetHexPerColor(float amount)
	{
		double num = (double)amount * 0.0627450980392157;
		float f = amount % 16f;
		int num2 = Mathf.FloorToInt((float)num);
		int num3 = Mathf.FloorToInt(f);
		string text = "";
		switch (num2)
		{
		case 0:
			text += 0;
			break;
		case 1:
			text += 1;
			break;
		case 2:
			text += 2;
			break;
		case 3:
			text += 3;
			break;
		case 4:
			text += 4;
			break;
		case 5:
			text += 5;
			break;
		case 6:
			text += 6;
			break;
		case 7:
			text += 7;
			break;
		case 8:
			text += 8;
			break;
		case 9:
			text += 9;
			break;
		case 10:
			text += "A";
			break;
		case 11:
			text += "B";
			break;
		case 12:
			text += "C";
			break;
		case 13:
			text += "D";
			break;
		case 14:
			text += "E";
			break;
		case 15:
			text += "F";
			break;
		default:
			Debug.Log("Invalid Value");
			break;
		}
		switch (num3)
		{
		case 0:
			text += 0;
			break;
		case 1:
			text += 1;
			break;
		case 2:
			text += 2;
			break;
		case 3:
			text += 3;
			break;
		case 4:
			text += 4;
			break;
		case 5:
			text += 5;
			break;
		case 6:
			text += 6;
			break;
		case 7:
			text += 7;
			break;
		case 8:
			text += 8;
			break;
		case 9:
			text += 9;
			break;
		case 10:
			text += "A";
			break;
		case 11:
			text += "B";
			break;
		case 12:
			text += "C";
			break;
		case 13:
			text += "D";
			break;
		case 14:
			text += "E";
			break;
		case 15:
			text += "F";
			break;
		default:
			Debug.Log("Invalid Value");
			break;
		}
		return text;
	}
}
