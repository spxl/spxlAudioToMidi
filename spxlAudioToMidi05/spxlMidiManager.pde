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
 */

import promidi.*;

public class MidiManager
{
  public static final int NUM_MIDI_CHANNELS = 16;

  protected static final int NO_MIDI_DEVICE = -1;
  protected static final String NO_MIDI_OUT_NAME = "No MIDI output";
  protected static final String NO_MIDI_IN_NAME = "No MIDI input";
  
  protected static final int NOT_SELECTED = -1;
  protected static final int SELECTED = 0;
  protected static final int SELECTING_DEVICE = 1;
  protected static final int SELECTING_CHANNEL = 2;
  
  int state = NOT_SELECTED;
  int prevState = state;
  
  // Parent PApplet
  protected PApplet p5;

  // MIDI IO
  public MidiIO midiIO;
  public MidiOut midiOut;

  protected int numOutputDevices;
  protected String[] outputDeviceNames;
  
  protected int outputChannel = 0;
  protected int outputDeviceNumber = NO_MIDI_DEVICE;
  protected String outputDeviceName = NO_MIDI_OUT_NAME;
  
  protected int numInputDevices;
  protected String[] inputDeviceNames;
  
  protected int inputChannel = 0;
  protected int inputDeviceNumber = NO_MIDI_DEVICE;
  protected String inputDeviceName = NO_MIDI_IN_NAME;
    
  // Text parameters
  public int textHeight = 14;
  public int textOffsetX = 1;
  public int textOffsetY = -2;

  // Display position, width, height
  public int x;
  public int y;
  public int w = 128;
  public int h = 2 * textHeight;

  // Mouse control information
  protected Point point;
  protected Point pointRel;
  protected boolean mouseOver = false;
  int numItems;
  protected int modifiersEx;

  // Constructor
  public MidiManager(PApplet p5)
  {
    this.p5 = p5;
    
    w = p5.width;

    // MIDI IO
    midiIO = MidiIO.getInstance(p5);
    midiIO.printDevices();
    
    updateDeviceNames();
    
    // GUI
    p5.registerMouseEvent(this);
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
    if (outputDeviceNumber == NO_MIDI_DEVICE)
    {
      outputChannel = channel;
      return;
    }

    // Use current output device
    setOutput(channel, outputDeviceNumber);
  }
  
  public void setOutputDevice(int deviceNumber)
  {
    // Use current output channel
    setOutput(outputChannel, deviceNumber);
  }
  
  public void setOutput(int channel, int deviceNumber)
  {
    println("setOutput(channel: " + channel + ", deviceNumber: " + deviceNumber + ")");
    if (deviceNumber < 0 || deviceNumber >= numOutputDevices)
      return;
      
    if (channel != outputChannel || deviceNumber != outputDeviceNumber)
    {
      try
      {
        int oldDeviceNumber = outputDeviceNumber;

        midiOut = midiIO.getMidiOut(channel, deviceNumber);
        outputChannel = channel;
        outputDeviceNumber = deviceNumber;
        outputDeviceName = outputDeviceNames[deviceNumber];
        println("MIDI output device: [" + outputDeviceName + "]");
        println("MIDI output channel: " + (outputChannel + 1));
        
//        if (oldDeviceNumber != NO_MIDI_DEVICE)
//          midiIO.closeOutput(oldDeviceNumber);
      }
      catch (Exception e)
      {
        String message = e.getMessage();
        println("getMidiOut() exception: " + message);
        midiOut = null;
        outputDeviceNumber = NO_MIDI_DEVICE;
        outputDeviceName = message;
      }
    }

    setState(outputDeviceNumber == NO_MIDI_DEVICE ? NOT_SELECTED : SELECTED);
  }
  
  public void setInputChannel(int channel)
  {
    if (inputDeviceNumber == NO_MIDI_DEVICE)
    {
      inputChannel = channel;
      return;
    }

    // Use current input device
    setInput(channel, inputDeviceNumber);
  }
  
  public void setInputDevice(int deviceNumber)
  {
    // Use current inputChannel
    setInput(inputChannel, deviceNumber);
  }
  
  public void setInput(int channel, int deviceNumber)
  {
    println("setInput(channel: " + channel + ", deviceNumber: " + deviceNumber + ")");
    
    if (deviceNumber < midiIO.numberOfInputDevices())
    {
      println("Opening MIDI input " + deviceNumber);

      try
      {
        midiIO.openInput(inputDeviceNumber, deviceNumber);
      }
      catch (Exception e)
      {
        String message = e.getMessage();
        println("openInput() exception: " + message);
        inputDeviceNumber = NO_MIDI_DEVICE;
        inputDeviceName = message;
        return;
      }
      
      inputDeviceName = midiIO.getInputDeviceName(inputDeviceNumber);
      inputDeviceNumber = deviceNumber;
      
      midiIO.plug(this, "plugController", inputDeviceNumber, inputChannel);
      
      println("MIDI controls plugged (device: " + inputDeviceNumber + "channel: " + (inputChannel + 1));
    }
  }

  void plugController(promidi.Controller controller)
  {
    print("plugController(): ");
    int num = controller.getNumber();
    int val = controller.getValue();
    println("num: " + num + ", val: " + val);

    if (num == 7) // Slider
    {
//      zoom = val / 64f;
//      println("Slider -> zoom: " + zoom);
    }
    else if (num == 10) // Knob
    {
//      setPeriod(64f / val);
//      println("Knob -> period: " + period);
    }
    else if (num == 16) // Top button
    {
//      togglePause();
//      println("Button -> paused: " + paused);
    }
    else if (num == 17) // Bottom button
    {
//      reverseDirection();
//      println("Button -> backwards: " + backwards);
    }
  }

  public void draw()
  {
    p5.pushStyle();
    
    // Solid background
    p5.noStroke();
    p5.fill(50);

    if (state == SELECTED)
    {
      p5.rect(x, y, w, 2 * textHeight);
      p5.fill(255);
      p5.text(outputDeviceName, x + textOffsetX, y + textHeight + textOffsetY);
      p5.text("Channel: " + nf(outputChannel + 1, 2), x + textOffsetX, y + 2 * textHeight + textOffsetY);
    }
    else if (state == SELECTING_DEVICE || state == SELECTING_CHANNEL)
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
      
      if (state == SELECTING_DEVICE)
      {
        p5.text("SELECT DEVICE:", x + textOffsetX, y + textHeight + textOffsetY);
        for (int i = 0; i < numOutputDevices; i++)
        {
          text(outputDeviceNames[i], x + textOffsetX, y + (i + 2) * textHeight + textOffsetY);
        }
        for (int i = 0; i < numInputDevices; i++)
        {
          text(inputDeviceNames[i], x + textOffsetX, y + (numOutputDevices + 2 + i) * textHeight + textOffsetY);
        }
      }
      else
      {
        p5.text("SELECT CHANNEL:", x + textOffsetX, y + textHeight + textOffsetY);
        for (int i = 1; i <= NUM_MIDI_CHANNELS; i++)
        {
          text("Channel " + nf(i, 2), x + textOffsetX, y + (i + 1) * textHeight + textOffsetY);
        }
      }
    }
    else
    {
      p5.rect(x, y, w, textHeight);
      p5.fill(255);
      p5.text("SELECT OUTPUT", x + textOffsetX, y + textHeight + textOffsetY);
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
      println("midiOut exception: " + message);
      midiOut = null;
      outputDeviceNumber = NO_MIDI_DEVICE;
      outputDeviceName = message;
    }
  }

  public void mouseEvent(MouseEvent event)
  {
    point = event.getPoint();
    pointRel = new Point(point.x - x, point.y - y);
    
    if ((pointRel.x >= 0) && (pointRel.x < w) && (pointRel.y >= 0) && (pointRel.y < h))
    {
      mouseOver = true;
    }
    else
    {
      mouseOver = false;
    }
    
    if (event.getID() != MouseEvent.MOUSE_PRESSED)
      return;

//          modifiersEx = event.getModifiersEx();
//          int onmask = MouseEvent.CTRL_DOWN_MASK | MouseEvent.BUTTON1_DOWN_MASK;
//          int offmask = MouseEvent.SHIFT_DOWN_MASK | MouseEvent.ALT_DOWN_MASK;

    if (state == NOT_SELECTED)
    {
      if (mouseOver)
        setState(SELECTING_DEVICE);
    }
    else if (state == SELECTED)
    {
      if (mouseOver)
        setState((pointRel.y < textHeight) ? SELECTING_DEVICE : SELECTING_CHANNEL);
    }
    else
    {
      // SELECTING_DEVICE or SELECTING_CHANNEL
      int itemNo = (int)(pointRel.y / textHeight) - 1;
      
      if (!mouseOver || itemNo < 0 || itemNo >= numItems)
      {
        setState(prevState);
      }
      else if (state == SELECTING_DEVICE)
      {
        if (itemNo < numOutputDevices)
          setOutputDevice(itemNo);
        else
          setInputDevice(itemNo - numOutputDevices);
      }
      else if (state == SELECTING_CHANNEL)
      {
        setOutputChannel(itemNo);
      }
    }
  }
  
  protected void setState(int newState)
  {
    prevState = state;
    state = newState;

    switch (state)
    {
      case NOT_SELECTED:      numItems = 0; break;
      case SELECTED:          numItems = 1; break;
      case SELECTING_DEVICE:  numItems = numOutputDevices + numInputDevices; break;
      case SELECTING_CHANNEL: numItems = NUM_MIDI_CHANNELS; break;
    }
    
    h = (numItems + 1) * textHeight;
  }
}

