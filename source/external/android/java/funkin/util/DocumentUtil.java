package funkin.util;

import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

import org.haxe.extension.Extension;

public class DocumentUtil
{
	public static boolean copyUriToFile(String uriString, String destPath)
	{
		if (Extension.mainActivity == null || uriString == null || destPath == null)
			return false;

		InputStream input = null;
		OutputStream output = null;

		try
		{
			File dest = new File(destPath);
			File parent = dest.getParentFile();
			if (parent != null && !parent.exists())
				parent.mkdirs();

			input = Extension.mainActivity.getContentResolver().openInputStream(Uri.parse(uriString));
			if (input == null)
				return false;

			output = new FileOutputStream(dest);

			byte[] buffer = new byte[16384];
			int read;
			while ((read = input.read(buffer)) != -1)
				output.write(buffer, 0, read);

			output.flush();
			return true;
		}
		catch (Exception e)
		{
			return false;
		}
		finally
		{
			try
			{
				if (input != null)
					input.close();
			}
			catch (Exception e) {}

			try
			{
				if (output != null)
					output.close();
			}
			catch (Exception e) {}
		}
	}

	public static boolean copyFileToUri(String srcPath, String uriString)
	{
		if (Extension.mainActivity == null || srcPath == null || uriString == null)
			return false;

		InputStream input = null;
		OutputStream output = null;

		try
		{
			input = new FileInputStream(new File(srcPath));
			output = Extension.mainActivity.getContentResolver().openOutputStream(Uri.parse(uriString), "wt");
			if (output == null)
				return false;

			byte[] buffer = new byte[16384];
			int read;
			while ((read = input.read(buffer)) != -1)
				output.write(buffer, 0, read);

			output.flush();
			return true;
		}
		catch (Exception e)
		{
			return false;
		}
		finally
		{
			try
			{
				if (input != null)
					input.close();
			}
			catch (Exception e) {}

			try
			{
				if (output != null)
					output.close();
			}
			catch (Exception e) {}
		}
	}

	public static String getDisplayName(String uriString)
	{
		if (Extension.mainActivity == null || uriString == null)
			return "";

		Cursor cursor = null;

		try
		{
			cursor = Extension.mainActivity.getContentResolver().query(Uri.parse(uriString), null, null, null, null);
			if (cursor != null && cursor.moveToFirst())
			{
				int index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
				if (index >= 0)
				{
					String name = cursor.getString(index);
					return name == null ? "" : name;
				}
			}
		}
		catch (Exception e) {}
		finally
		{
			if (cursor != null)
				cursor.close();
		}

		return "";
	}
}
