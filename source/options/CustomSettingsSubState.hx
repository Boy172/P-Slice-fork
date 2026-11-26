package options;

import options.Option;

class CustomSettingsSubState extends BaseOptionsMenu
{
	public function new(id:String, name:String)
	{
		title = name;
		rpcTitle = '$name settings menu';

		for (option in CustomSettings.optionsForSection(id))
			addOption(option);

		super();
	}
}
