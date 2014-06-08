  /**
 * spxlMidiManager.pde
 * 2010-06-25 by subpixel
 * http://subpixels.com
 *
 * Midi Manager
 *
 * 2010-06-25 Fri - v04 subpixel
 * - Created
 *
 * 2010-06-27 Sun - v05 subpixel
 * - Use Midi input to control monitor parameters
 * - INCOMPLETE
 *
 * 2013-08-13 Tue - v06 subpixel
 * - MouseEvent changes for Processing 2.0
 *   p5.registerMouseEvent(this); replaced by p5.registerMethod("mouseEvent", this);
 *   java.awt.event.MouseEvent replaced by processing.event.MouseEvent
 *   point = event.getPoint(); replaced by point = new Point(event.getX(), event.getY());
 *   event.getID() replaced by event.getAction(), constants also changed
 * 2013-08-14 Wed - v06 subpixel
 * - Replace java.awt.Point by PVector
 *
 * 2014-06-06 Fri - v07 subpixel
 * - Show MIDI channel when device not chosen since channel can be changed before device chosen
 * - Implement MIDI input to control meter monitors
 *
 * 2014-06-08 Sun - v08 subpixel
 * - Rejig MidiManager menu system:
 *    MIDI input and MIDI output selectable
 *    Click channel number to get channel menu, click device name to get device menu
 */

import java.util.Observable;

import promidi.*;

public class MidiManager extends Observable
{
  public static final int NUM_MIDI_CHANNELS = 16;

  protected static final int NO_MIDI_DEVICE = -1;
  protected static final String NO_MIDI_OUT_NAME = "No MIDI output";
  protected static final String NO_MIDI_IN_NAME = "No MIDI input";
  
  protected static final int NO_MENU = 0;
  protected static final int SELECTING_INPUT_DEVICE   = 1;
  protected static final int SELECTING_INPUT_CHANNEL  = 2;
  protected static final int SELECTING_OUTPUT_DEVICE  = 3;
  protected static final int SELECTING_OUTPUT_CHANNEL = 4;
  
  int menuState = NO_MENU;
  int prevState = menuState;
  
  // Parent PApplet
  protected PApplet p5;

  // MIDI IO
  public MidiIO midiIO;
  public MidiOut midiOut;
  
  protected Object plugSetupObject;
  protected String plugSetupMethod;

  protected int numOutputDevices;
  protected String[] outputDeviceNames;
  
  protected int numInputDevices;
  protected String[] inputDeviceNames;
  
  protected int inputChannel = 0;
  protected int inputDeviceNumber = NO_MIDI_DEVICE;
  protected String inputDeviceName = NO_MIDI_IN_NAME;

  protected int outputChannel = 0;
  protected int outputDeviceNumber = NO_MIDI_DEVICE;
  protected String outputDeviceName = NO_MIDI_OUT_NAME;
  
  // Text parameters
  public int textHeight = 14;
  public int textOffsetX = 1;
  public int textOffsetY = -2;

  public int channelWidth = 20; // Width of channel number display / menu hotzone
  
  // Display position, width, height
  public int x;
  public int y;
  public int w = 128;
  public int h = 2 * textHeight;

  // Mouse control information
  protected PVector point;
  protected PVector pointRel;
  protected boolean mouseOver = false;
  int numItems;
  protected int modifiersEx;

  // Constructor
  public MidiManager(PApplet p5)
  {
    this.p5 = p5;
    
    w = p5.width;
    channelWidth = (int)(p5.textWidth("00 "));

    // MIDI IO
    midiIO = MidiIO.getInstance(p5);
    midiIO.printDevices();
    
    updateDeviceNames();
    
    // GUI
    p5.registerMethod("mouseEvent", this);
  }
  
  public void updateDeviceNames()
  {
    numOutputDevices = midiIO.numberOfOutputDevices();
    outputDeviceNames = new String[numOutputDevices];
    
    for (int i = 0; i < numOutputDevices; i++)
    {
      outputDeviceNames[i] = midiIO.getOutputDeviceName(i);
    }

    numInputDevices = midiIO.numberOfInputDevices();
    inputDeviceNames = new String[numInputDevices];
    
    for (int i = 0; i < numInputDevices; i++)
    {
      inputDeviceNames[i] = midiIO.getInputDeviceName(i);
    }
  }
  
  public void setOutputChannel(int channel)
  {
    p5.println("setOutputChannel(" + channel + ")");
    if (outputDeviceNumber == NO_MIDI_DEVICE)
    {
      outputChannel = channel;
      p5.println("  channel stored");
      return;
    }

    // Use current output device
    setOutput(channel, outputDeviceNumber);
  }
  
  public void setOutputDevice(int deviceNumber)
  {
    p5.println("setOutputDevice(" + deviceNumber + ")");
    
    // Use current output channel
    setOutput(outputChannel, deviceNumber);
  }
  
  public void setOutput(int channel, int deviceNumber)
  {
    p5.println("setOutput(channel: " + channel + ", deviceNumber: " + deviceNumber + ")");
    if (deviceNumber < 0 || deviceNumber >= numOutputDevices)
      return;

    String deviceName = outputDeviceNames[deviceNumber];
    p5.println ("  Device name: " + deviceName);
    
    if (channel != outputChannel || deviceNumber != outputDeviceNumber)
    {
      try
      {
        p5.println("  Opening MIDI output...");
        midiOut = midiIO.getMidiOut(channel, deviceNumber);

        outputChannel = channel;
        outputDeviceNumber = deviceNumber;
        outputDeviceName = outputDeviceNames[deviceNumber];
//        p5.println("  MIDI output device: [" + outputDeviceName + "]");
//        p5.println("  MIDI output channel: " + (outputChannel + 1));
      }
      catch (Exception e)
      {
        String message = e.getMessage();
        p5.println("** getMidiOut() exception: " + message);
        midiOut = null;
        outputDeviceNumber = NO_MIDI_DEVICE;
        outputDeviceName = message;
      }
    }

    setState(NO_MENU); //TODO: leave up to caller?
  }
  
  public void setInputChannel(int channel)
  {
    p5.println("setInputChannel(" + channel + ")");
    
    if (inputDeviceNumber == NO_MIDI_DEVICE)
    {
      inputChannel = channel;
      p5.println("  channel stored");
      return;
    }

    // Use current input device
    setInput(channel, inputDeviceNumber);
  }
  
  public void setInputDevice(int deviceNumber)
  {
    p5.println("setInputDevice(" + deviceNumber + ")");
    
    // Use current inputChannel
    setInput(inputChannel, deviceNumber);
  }
  
  public void setInput(int channel, int deviceNumber)
  {
    p5.println("setInput(channel: " + channel + ", deviceNumber: " + deviceNumber + ")");
    
    if (deviceNumber < 0 || deviceNumber >= numInputDevices)
      return;
    
    String deviceName = inputDeviceNames[deviceNumber];
    p5.println ("  Device name: " + deviceName);
    
    if (channel != inputChannel || deviceNumber != inputDeviceNumber)
    {
      if (inputDeviceNumber != NO_MIDI_DEVICE)
      {
        try
        {
          p5.println("  Closing MIDI input " + inputDeviceNumber + " ...");
          midiIO.closeInput(inputDeviceNumber);
        }
        catch (Exception e)
        {
          String message = e.getMessage();
          p5.println("** closeInput() exception: " + message);
          inputDeviceNumber = NO_MIDI_DEVICE;
          inputDeviceName = message;
        }
      }
      
      try
      {
        p5.println("  Opening MIDI input...");
        midiIO.openInput(deviceNumber, channel);
        
        inputChannel = channel;
        inputDeviceNumber = deviceNumber;
        inputDeviceName = inputDeviceNames[deviceNumber];
//        p5.println(" MIDI input device: [" + inputDeviceName + "]");
//        p5.println(" MIDI input channel: " + (inputChannel + 1));
      }
      catch (Exception e)
      {
        String message = e.getMessage();
        p5.println("** openInput() exception: " + message);
        inputDeviceNumber = NO_MIDI_DEVICE;
        inputDeviceName = message;
      }

      // Do the plugging
      doPlugSetup();
    }
  }

  public void setPlugSetup(Object plugSetupObject, String plugSetupMethod)
  {
    p5.println("setPlugSetup(plugSetupObject, \"" + plugSetupMethod + "\")");
    this.plugSetupObject = plugSetupObject;
    this.plugSetupMethod = plugSetupMethod;
  }

  public void doPlugSetup()
  {
    p5.println("doPlugSetup()");
    
    if (plugSetupObject == null || plugSetupMethod == null || plugSetupMethod.length() == 0)
    {
      p5.println("  plugSetupObject/Method not initialised");
      return;
    }
    
    try
    {
      plugSetupObject.getClass().getMethod(plugSetupMethod).invoke(plugSetupObject);
    }
    catch (Exception e)
    {
      p5.println("** doPlugSetup() failed: " + e.getMessage());
    }
  }
    
  public void setPlug(Object plugObject, String plugMethod)
  {
    p5.println("setPlug(plugobject, \"" + plugMethod + "\")");
    
    if (inputDeviceNumber < 0 || inputDeviceNumber >= numInputDevices)
    {
      p5.println("** Set inputDevice first!");
      return;
    }
    
    String deviceName = inputDeviceNames[inputDeviceNumber];
    p5.println("  Device: " + inputDeviceNumber + " (" + deviceName + "), channel: " + (inputChannel + 1));
    
    try
    {
      midiIO.plug(plugObject, plugMethod, inputDeviceNumber, inputChannel);
    }
    catch (Exception e)
    {
      String message = e.getMessage();
      p5.println("** setPlug() exception: " + message);
    }
  }

//  void plugController(promidi.Controller controller)
//  {
//    print("plugController(): ");
//    int num = controller.getNumber();
//    int val = controller.getValue();
//    p5.println("num: " + num + ", val: " + val);
//    
//    if (num == 7) // Slider
//    {
//    }
//    else if (num == 10) // Knob
//    {
//    }
//    else if (num == 16) // Top button
//    {
//    }
//    else if (num == 17) // Bottom button
//    {
//    }
//  }

  public void draw()
  {
    p5.pushStyle();
    
    // Solid background
    p5.noStroke();
    p5.fill(50);

    if (menuState == NO_MENU)
    {
      p5.rect(x, y, w, 2 * textHeight);
      
      // Different colour for channel number
      p5.fill(0, 0, 60);
      p5.rect(x, y, channelWidth, 2 * textHeight);
      
      
      String outputStr = p5.nf(outputChannel + 1, 2) + " ";
      String inputStr = p5.nf(inputChannel + 1, 2) + " ";

      p5.fill(255, 255, 0);
      p5.text(inputStr, x + textOffsetX, y + textHeight + textOffsetY);
      p5.text(outputStr, x + textOffsetX, y + 2 * textHeight + textOffsetY);

      p5.fill(255);
      p5.text(" " + inputDeviceName, x + textOffsetX + channelWidth, y + textHeight + textOffsetY);
      p5.text(" " + outputDeviceName, x + textOffsetX + channelWidth, y + 2 * textHeight + textOffsetY);
    }
    else // Selecting a menu item
    {
      p5.rect(x, y, w, (numItems + 1) * textHeight);

      // Hilight
      if (mouseOver)
      {
        int itemNo = (int)(pointRel.y / textHeight) - 1;
        if (itemNo >= 0 && itemNo < numItems)
        {
          p5.fill(100);
          p5.rect(x, y + (itemNo + 1) * textHeight, w, textHeight);
        }
      }
      
      p5.fill(255);
      
      if (menuState == SELECTING_INPUT_DEVICE)
      {
        p5.text("INPUT DEVICE:", x + textOffsetX, y + textHeight + textOffsetY);
        for (int i = 0; i < numInputDevices; i++)
        {
          p5.text(inputDeviceNames[i], x + textOffsetX, y + (i + 2) * textHeight + textOffsetY);
        }
      }
      else if (menuState == SELECTING_OUTPUT_DEVICE)
      {
        p5.text("OUTPUT DEVICE:", x + textOffsetX, y + textHeight + textOffsetY);
        for (int i = 0; i < numOutputDevices; i++)
        {
          p5.text(outputDeviceNames[i], x + textOffsetX, y + (i + 2) * textHeight + textOffsetY);
        }
      }
      else
      {
        String menuTitle = (menuState == SELECTING_INPUT_CHANNEL) ? "INPUT CHANNEL:" : "OUTPUT CHANNEL:";
        p5.text(menuTitle, x + textOffsetX, y + textHeight + textOffsetY);
        for (int i = 1; i <= NUM_MIDI_CHANNELS; i++)
        {
          text("Channel " + nf(i, 2), x + textOffsetX, y + (i + 1) * textHeight + textOffsetY);
        }
      }
    }
    
    p5.popStyle();
  }

  public void outputControl(int controllerNumber, int value)
  {
    if (midiOut == null)
      return;
    
    promidi.Controller cc =
      new promidi.Controller(controllerNumber, value);

    try
    {
      midiOut.sendController(cc);
    }
    catch (Exception e)
    {
      String message = e.getMessage();
      p5.println("** midiOut.sendController() exception: " + message);
      midiOut = null;
      outputDeviceNumber = NO_MIDI_DEVICE;
      outputDeviceName = message;
    }
  }

  public void mouseEvent(MouseEvent event)
  {
    point = new PVector(event.getX(), event.getY());
    pointRel = new PVector(point.x - x, point.y - y);
    
    if ((pointRel.x >= 0) && (pointRel.x < w) && (pointRel.y >= 0) && (pointRel.y < h))
    {
      mouseOver = true;
    }
    else
    {
      mouseOver = false;
    }
    
    if (event.getAction() != MouseEvent.PRESS)
      return;

    if (menuState == NO_MENU)
    {
      if (mouseOver)
      {
        boolean selectChannel = (pointRel.x < channelWidth);
        
        if (pointRel.y < textHeight)
        {
          setState(selectChannel ? SELECTING_INPUT_CHANNEL : SELECTING_INPUT_DEVICE);
        }
        else if (pointRel.y < 2 * textHeight)
        {
          setState(selectChannel ? SELECTING_OUTPUT_CHANNEL : SELECTING_OUTPUT_DEVICE);
        }
      }
    }
    else
    {
      // SELECTING_INPUT_DEVICE or SELECTING_INPUT_CHANNEL
      int itemNo = (int)(pointRel.y / textHeight) - 1;
      
      if (!mouseOver || itemNo < 0 || itemNo >= numItems)
      {
        setState(prevState);
      }
      else if (menuState == SELECTING_INPUT_DEVICE)
      {
        setInputDevice(itemNo);
      }
      else if (menuState == SELECTING_OUTPUT_DEVICE)
      {
          setOutputDevice(itemNo);
      }
      else if (menuState == SELECTING_INPUT_CHANNEL)
      {
        setInputChannel(itemNo);
      }
      else if (menuState == SELECTING_OUTPUT_CHANNEL)
      {
        setOutputChannel(itemNo);
      }

      // Done with menu selection      
      setState(NO_MENU);
    }
  }
  
  protected void setState(int newState)
  {
    prevState = menuState;
    menuState = newState;

    switch (menuState)
    {
      case NO_MENU:      numItems = 1; break; // No "menu title", but two spots to click
      case SELECTING_INPUT_DEVICE:  numItems = numInputDevices; break;
      case SELECTING_INPUT_CHANNEL: numItems = NUM_MIDI_CHANNELS; break;
      case SELECTING_OUTPUT_DEVICE:  numItems = numOutputDevices; break;
      case SELECTING_OUTPUT_CHANNEL: numItems = NUM_MIDI_CHANNELS; break;
    }
    
    h = (numItems + 1) * textHeight;
  }
}

