package funkin.util;

import android.app.Activity;
import android.graphics.Point;
import android.util.Log;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;

import org.haxe.extension.Extension;

public class ResolutionUtil
{
	static SurfaceView findSurface(View view)
	{
		if (view instanceof SurfaceView)
			return (SurfaceView) view;

		if (view instanceof ViewGroup)
		{
			ViewGroup group = (ViewGroup) view;
			for (int i = 0; i < group.getChildCount(); i++)
			{
				SurfaceView found = findSurface(group.getChildAt(i));
				if (found != null)
					return found;
			}
		}

		return null;
	}

	public static boolean setScale(final float scale)
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null)
			return false;

		activity.runOnUiThread(new Runnable()
		{
			public void run()
			{
				try
				{
					SurfaceView surface = findSurface(activity.getWindow().getDecorView());
					if (surface == null)
						return;

					SurfaceHolder holder = surface.getHolder();

					if (Math.abs(scale - 1f) < 0.001f)
					{
						holder.setSizeFromLayout();
						return;
					}

					Point size = new Point();
					activity.getWindowManager().getDefaultDisplay().getRealSize(size);
					holder.setFixedSize(Math.max(1, Math.round(size.x * scale)), Math.max(1, Math.round(size.y * scale)));
				}
				catch (Throwable error)
				{
					Log.e("ResolutionUtil", "setScale failed", error);
				}
			}
		});

		return true;
	}
}
