import std.stdio;
import std.file;
import std.path;
import std.conv;
import std.string;
import std.process;
import std.regex;
import std.typecons;

import gtk.Dialog;
import gtk.Main;
import gtk.Image;
import gtk.Label;
import gtk.EditableIF;
import gtk.HBox;
import gtk.VBox;
import gtk.ScrolledWindow;
import gtk.Adjustment;
import gtk.Entry;
import gtk.CheckButton;
import gtk.ComboBoxText;
import gtk.SpinButton;
import gtk.MessageDialog;
import gtkc.gtktypes;

string[string] writeTypes;

enum res = ctRegex!`(\d+)x(\d+)`;

class ConvertWindow : Dialog
{
public:
	this(string file, string info)
	{
		super();

		this.file = file;
		auto match = info.matchFirst(res);
		imgWidth = match[1].to!int;
		imgHeight = match[2].to!int;

		setTitle("Image Conversion");

		addButton("OK", 0);
		addButton("All", 1);
		addButton("Skip", 2);
		addButton("Cancel", 3);

		ScrolledWindow imageHost = new ScrolledWindow(null, null);
		imageHost.add(new Image(file));
		getContentArea().packStart(imageHost, true, true, 0);
		getContentArea().add(new Label(file));
		getContentArea().add(new Label(info));

		auto convert = new HBox(false, 2);
		convert.add(new CheckButton("Convert:", &convertBtn_click));
		auto convertContent = new HBox(false, 2);
		convertType = new ComboBoxText(false);
		foreach (type, ext; writeTypes)
			convertType.insertText(-1, type);
		jpgQuality = new SpinButton(0, 100, 1);
		jpgQuality.setValue(85);
		convertType.setSensitive(false);
		jpgQuality.setSensitive(false);
		convertContent.add(convertType);
		convertContent.add(new Label("Quality:"));
		convertContent.add(jpgQuality);
		convert.packEnd(convertContent, true, true, 2);

		auto rotate = new HBox(false, 2);
		rotate.add(new CheckButton("Rotate:", &rotateBtn_click));
		rotateAmount = new SpinButton(-360, 360, 90);
		rotateAmount.setValue(0);
		rotateAmount.setSensitive(false);
		rotate.packEnd(rotateAmount, true, true, 2);

		auto resize = new HBox(false, 2);
		resize.add(new CheckButton("Resize:", &resizeBtn_click));
		auto resizeContent = new HBox(false, 2);
		resizeContent.packStart(resizeType = new ComboBoxText(false), true, true, 2);
		resizeType.insertText(-1, "Custom size");
		resizeType.insertText(-1, "640x400");
		resizeType.insertText(-1, "800x600");
		resizeType.insertText(-1, "1024x768");
		resizeType.insertText(-1, "1600x1200");
		resizeType.insertText(-1, "1920x1080");
		resizeType.insertText(-1, "Enlarge to 400%");
		resizeType.insertText(-1, "Enlarge to 300%");
		resizeType.insertText(-1, "Enlarge to 200%");
		resizeType.insertText(-1, "Enlarge to 150%");
		resizeType.insertText(-1, "Reduce to 75%");
		resizeType.insertText(-1, "Reduce to 50%");
		resizeType.insertText(-1, "Reduce to 25%");
		resizeContent.add(width = new Entry(""));
		resizeContent.add(new Label("x"));
		resizeContent.add(height = new Entry(""));
		resizeType.setSensitive(false);
		width.setSensitive(false);
		height.setSensitive(false);
		resize.packEnd(resizeContent, true, true, 2);

		getContentArea().add(convert);
		getContentArea().add(rotate);
		getContentArea().add(resize);
		getContentArea().add(addSuffix = new CheckButton("Add filename suffix"));

		showAll();
	}

	bool shouldConvert() @property
	{
		return doConvert && convertType.getActiveText().length > 0;
	}

	bool shouldRotate() @property
	{
		return doRotate && rotateAmount.getValueAsInt() != 0;
	}

	bool shouldResize() @property
	{
		return doResize && resizeType.getActiveText().length > 0;
	}

	string[] extraFlags() @property
	{
		if (convertType.getActiveText() == "JPEG"
				|| convertType.getActiveText() == "PNG" || convertType.getActiveText() == "TIFF")
			return ["-quality", jpgQuality.getValueAsInt().to!string];
		return [];
	}

	@property ref auto filePath()
	{
		return file;
	}

	string outputFile() @property
	{
		string output = file;
		if (shouldConvert)
			output = output.setExtension(writeTypes[convertType.getActiveText()]);
		if (addSuffix.getActive() && (shouldRotate || shouldResize))
		{
			string ext = output.extension;
			output = output.stripExtension();
			if (shouldRotate)
			{
				output ~= "-r" ~ rotation;
			}
			if (shouldResize)
			{
				auto newSize = size;
				if (newSize[0])
					output ~= newSize[1] ~ 'x' ~ newSize[2];
				else
					output ~= newSize[1];
			}
			output ~= ext;
		}
		return output;
	}

	string rotation() @property
	{
		return rotateAmount.getValueAsInt().to!string;
	}

	auto size() @property
	{
		switch (resizeType.getActiveText())
		{
		case "Custom size":
			return tuple(true, width.getText(), height.getText());
		case "640x400":
			return tuple(true, "640", "400");
		case "800x600":
			return tuple(true, "800", "600");
		case "1024x768":
			return tuple(true, "1024", "768");
		case "1600x1200":
			return tuple(true, "1600", "1200");
		case "1920x1080":
			return tuple(true, "1920", "1080");
		case "Enlarge to 400%":
			return tuple(false, "400%", "");
		case "Enlarge to 300%":
			return tuple(false, "300%", "");
		case "Enlarge to 200%":
			return tuple(false, "200%", "");
		case "Enlarge to 150%":
			return tuple(false, "150%", "");
		case "Reduce to 75%":
			return tuple(false, "75%", "");
		case "Reduce to 50%":
			return tuple(false, "50%", "");
		case "Reduce to 25%":
			return tuple(false, "25%", "");
		default:
			assert(0, "Not implemented");
		}
	}

private:
	void convertBtn_click(CheckButton btn)
	{
		convertType.setSensitive(btn.getActive());
		jpgQuality.setSensitive(btn.getActive());
		doConvert = btn.getActive();
	}

	void rotateBtn_click(CheckButton btn)
	{
		rotateAmount.setSensitive(btn.getActive());
		doRotate = btn.getActive();
	}

	void resizeBtn_click(CheckButton btn)
	{
		resizeType.setSensitive(btn.getActive());
		if (!btn.getActive())
		{
			width.setSensitive(false);
			height.setSensitive(false);
		}
		else
			updateResize();
		doResize = btn.getActive();
	}

	void updateResize()
	{
		if (resizeType.getActiveText() == "Custom size")
		{
			width.setSensitive(true);
			height.setSensitive(true);
		}
		else
		{
			width.setSensitive(false);
			height.setSensitive(false);
		}
	}

	CheckButton addSuffix;
	ComboBoxText convertType;
	SpinButton jpgQuality;
	SpinButton rotateAmount;
	ComboBoxText resizeType;
	Entry width, height;
	bool doConvert, doRotate, doResize;
	string file;
	int imgWidth, imgHeight;
}

string identify(string file)
{
	string output = execute(["identify", file]).output;
	if (output[0 .. file.length] != file)
		return "";
	auto start = file.length + 1;
	auto end = output.indexOf("bit");
	if (end == -1)
		end = output.length;
	else
		end += 3;
	return output[start .. end];
}

void magick(string file, string[] args)
{
	execute(["convert", file] ~ args);
}

void main(string[] args)
{
	if (args.length <= 1)
	{
		writeln("Usage: ", args[0], " imagefiles...");
		return;
	}
	writeTypes = ["GIF" : ".gif", "JPEG" : ".jpg", "PNG" : ".png",
		"Windows Bitmap" : ".bmp", "DDS" : ".dds", "HDR" : ".hdr",
		"Photoshop File" : ".psd", "TIFF" : ".tiff", "Text File" : ".txt"];
	Main.init(args);
	ConvertWindow convert;
	bool forAll = false;
	bool converted = false;
	foreach (file; args[1 .. $])
	{
		immutable info = file.identify;
		if (info == "")
			continue;

		if (!forAll)
		{
			convert = new ConvertWindow(file, info);
			immutable response = convert.run();
			if (response == 3)
				return;
			if (response == 2)
				continue;
			if (response == 1)
				forAll = true;
			convert.hide();
		}

		convert.filePath = file;

		if (convert.shouldConvert || convert.shouldResize || convert.shouldRotate)
		{
			string[] flags;
			if (convert.shouldResize)
			{
				auto resize = convert.size;
				if (resize[0])
				{
					string amount;
					if (resize[1].length > 0)
						amount = resize[1];
					if (resize[2].length > 0)
						amount ~= 'x' ~ resize[2];
					if (amount.length > 0)
						flags ~= ["-resize", amount];
				}
				else
				{
					flags ~= ["-resize", resize[1]];
				}
			}
			if (convert.shouldRotate)
				flags ~= ["-rotate", convert.rotation];
			magick(file, flags ~ convert.extraFlags ~ convert.outputFile);
		}

		converted = true;
	}

	if (!converted)
		new MessageDialog(null, cast(GtkDialogFlags) 0, GtkMessageType.ERROR, GtkButtonsType.OK,
			"The specified files can not be converted!").run();
}
