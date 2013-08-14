/**
 * spxlMeterMonitor.pde
 * 2010-06-24 by subpixel
 * http://subpixels.com
 *
 * Meter monitor that outputs MIDI data
 *
 * 2010-06-24 Thu - v03 subpixel
 * - Created
 *
 * 2010-06-25 Thu - v04 subpixel
 * - Replace midiOut with midiManager
 * - Improved GUI handling using "state"
 * - Ctrl+drag for meter linking replaced by click+drag slightly to left of monitor
 * - Click (+optionally drag) near top to adjust max, near bottom to adjust min
 * - Dragging above or below monitor (whilst adjusting min/max) snaps to previous min/max value
 * - Right click monitor  to reset to full range
 * - Right click link target to reset link to original meter
 * - Display value (in decimal and hex) when hovering over monitor
 * - Display min/max value when adjusting
 * - Option to display hex or decimal values
 *
 * 2013-08-13 Tue - v06 subpixel
 * - MouseEvent changes for Processing 2.0
 *   p5.registerMouseEvent(this); replaced by p5.registerMethod("mouseEvent", this);
 *   java.awt.event.MouseEvent replaced by processing.event.MouseEvent
 *   point = event.getPoint(); replaced by point = new Point(event.getX(), event.getY());
 *   event.getModifiersEx() bit masking replaced by event.getButton()
 *   event.getID() replaced by event.getAction(), constants also changed
 * - New: isMouseOverY(), isMouseOver(), isMouseOverLink()
 * 2013-08-14 Wed - v06 subpixel
 * - Replace java.awt.Point by PVector
 */

import processing.event.MouseEvent;

public class MeterMonitor
{
  protected static final int STATE_NORMAL = 0;
  protected static final int STATE_SET_MIN = 1;
  protected static final int STATE_SET_MAX = 2;
  protected static final int STATE_SET_LINK = 4;
  
  // Parent PApplet
  protected PApplet p5;

  // Meters array
  protected Meter[] meters;
  
  // Index of meter to monitor
  protected int meterIndex;
  
  // Initial setting of meterIndex (for connection reset)
  protected int originalMeterIndex;
  
  // Reference for indexed meter being monitored
  protected Meter meter;
  
  // Midi output
  protected MidiManager midiManager;
  
  public static final int MIN_CONTROLLER_VALUE = 0;
  public static final int MAX_CONTROLLER_VALUE = 127;
  
  int controllerNumber = 0;

  // Controller value range
  int controllerMinValue = MIN_CONTROLLER_VALUE;
  int controllerMaxValue = MAX_CONTROLLER_VALUE;
  
  // Previous controller range values
  // (Used in states STATE_SET_MAX, STATE_SET_MIN for backup)
  int prevControllerMinValue = controllerMinValue;
  int prevControllerMaxValue = controllerMaxValue;

  // Current output position, as read from linked meter
  protected float position = 0f;

  // Output value, based on position and controller value range
  protected int value = controllerMinValue;
  
  // Previous output value (emitted MIDI control)
  protected int prevOutputValue = -1;
  
  // Text parameters
  protected int textOffsetX = 2;
  protected int textOffsetY = 12;

  // Display position, width, height
  int x;
  int y;
  int w = 100;
  int h = 10;
  
  // Mouse control information
  protected int state = STATE_NORMAL;
  PVector point; // Mouse coordinates
  PVector pointRel; // Mouse coordinates relative to monitor position
  boolean mouseOver = false; // Mouse over meter?
  boolean mouseOverY = false; // Mouse at least on same row as meter?
  boolean mouseOverLink = false; // Mouse over meter link (just to left)?
  int mouseValue = 0; // Controller value for mouse position

  protected boolean pressed = false;
  protected int modifiersEx;

  // Constructor
  public MeterMonitor(PApplet p5,
                      Meter[] meters, int meterIndex,
                      MidiManager midiManager, int controllerNumber)
  {
    this.p5 = p5;
    this.meters = meters;
    originalMeterIndex = meterIndex;
    setMeterLink(originalMeterIndex);
    this.midiManager = midiManager;
    this.controllerNumber = controllerNumber;

    p5.registerMethod("mouseEvent", this);//GRW Processing 2.0 changes
  }
  
  public void draw()
  {
    int x1 = x + (int)((float)controllerMinValue / MAX_CONTROLLER_VALUE * (w - 1));
    int x2 = x + (int)((float)controllerMaxValue / MAX_CONTROLLER_VALUE * (w - 1));
    int pw = (int)(position * (x2 - x1));
    
    int yMid = y + (h >> 1);
    
    p5.pushStyle();
    
    // Connection from meter
    if (mouseOverLink || state == STATE_SET_LINK)
      p5.stroke(255, 255, 0);
    else
      p5.stroke(100);

    p5.smooth();
    p5.line(meter.x + meter.w, meter.y + (meter.h >> 1), x, y + (h >> 1));
    p5.noSmooth();

    // Solid background
    p5.noStroke();
    p5.fill(20);
    p5.rect(x, y, w, h);
    
    // Output range
    p5.fill(50);
    p5.rect(x1, y, x2 - x1, h);

    // Output position
    p5.fill(50 + position * 206, 50, 150 - position * 255);
    p5.noStroke();
    p5.rect(x1, y + 2, pw, h - 4);

    // Position output line
    p5.stroke(255);
    p5.line(x1 + pw, y + 2, x1 + pw, y + h - 3);
    
    // Display value when setting min or max
    if (state == STATE_SET_MIN)
    {
      p5.fill(255);
      text("Min: " + dispValue(controllerMinValue), x + textOffsetX, y + textOffsetY);
    }
    else if (state == STATE_SET_MAX)
    {
      p5.fill(255);
      text("Max: " + dispValue(controllerMaxValue), x + textOffsetX, y + textOffsetY);
    }
    else if (mouseOver)
    {
      p5.fill(255);
      text(controllerNumber + ": " + dispValue(value), x + textOffsetX, y + textOffsetY);
    }
    
    // Show link hotspot
    if (mouseOverLink || state == STATE_SET_LINK)
    {
      p5.stroke(200, 200, 0);
      p5.fill(255, 0, 0);
      p5.ellipse(x, y + h / 2, 10, 10);

      p5.fill(255);
      text("Drag to\nmeter", x + h / 4 + textOffsetX, y + textOffsetY);
    }
    
    // Show possible new connection (draw to mouse location)
    if (state == STATE_SET_LINK)
    {
      p5.stroke(255);
      p5.line(point.x, point.y, x, y + (h >> 1));
    }
    
    p5.popStyle();
  }
  
  String dispValue(int n)
  {
    return displayHex ? hex(n, 2) : nf(n, 3);
  }
  
  public boolean isMouseOverY()
  {
    return mouseOverY;
  }

  public boolean isMouseOver()
  {
    return mouseOver;
  }

  public boolean isMouseOverLink()
  {
    return mouseOverLink;
  }

  // Update the monitor value and position
  // Emit a MIDI controller message if there is a change
  public void update()
  {
    position = meter.position;
    value = (int)lerp(controllerMinValue, controllerMaxValue, position);

    outputMidiControl();
  }
  
  // Output a Midi control message for the current value
  // (if value differs from previous output value)
  public void outputMidiControl()
  {
    if (midiManager != null && value != prevOutputValue)
    {
      midiManager.outputControl(controllerNumber, value);
      prevOutputValue = value;
    }
  }

  public void mouseEvent(MouseEvent event)
  {
    point = new PVector(event.getX(), event.getY());
    pointRel = new PVector(point.x - x, point.y - y);
    
    int button = event.getButton();
    boolean leftButton = (button == LEFT);
    boolean rightButton = (button == RIGHT);

    mouseOver = false;
    mouseOverY = false;
    mouseOverLink = false;
    mouseValue = MIN_CONTROLLER_VALUE;
    
    if ((pointRel.y >= 0) && (pointRel.y < h))
    {
      mouseOverY = true;
      
      if ((pointRel.x >= 0) && (pointRel.x < w))
      {
        mouseOver = true;
        mouseValue = (int)(0.5f + map(pointRel.x, 0, w - 1, MIN_CONTROLLER_VALUE, MAX_CONTROLLER_VALUE));
      }
      else if (pointRel.x >= w)
      {
        mouseValue = MAX_CONTROLLER_VALUE;
      }
      else if ((state == STATE_NORMAL) && (pointRel.x >= -h / 2) && (pointRel.x < 0))
      {
        mouseOverLink = true;
      }
    }

    // What kind of mouse event was it?
    int action = event.getAction();
    
    if (state == STATE_NORMAL)
    {
      if (action == MouseEvent.PRESS)
      {
        if (mouseOverLink)
        {
          // Right click to reset link
          if (rightButton)
          {
            resetMeterLink();
          }
          // Left drag to set new link
          else
          {
            setState(STATE_SET_LINK);
          }
        }
        else if (mouseOver)
        {
          // Right-click to reset min & max
          if (rightButton)
          {
            resetOutputRange();
          }
          // Set minimum if clicked near bottom of monitor
          else if (pointRel.y > h * 3 / 4)
          {
            setState(STATE_SET_MIN);
            prevControllerMinValue = controllerMinValue;
            controllerMinValue = mouseValue;
            update();
          }
          // Set maximum if clicked near top of monitor
          else
          {
            setState(STATE_SET_MAX);
            prevControllerMaxValue = controllerMaxValue;
            controllerMaxValue = mouseValue;
            update();
          }
        }
      }
    }
    else if (state == STATE_SET_MAX || state == STATE_SET_MIN)
    {
      // Set the min or max value when dragging, change state on release
      if (action == MouseEvent.RELEASE)
      {
        setState(STATE_NORMAL);
      }
      else if (mouseOverY)
      {
        if (state == STATE_SET_MAX)
          controllerMaxValue = mouseValue;
        else
          controllerMinValue = mouseValue;
        
        update();
      }
      else
      {
        if (state == STATE_SET_MAX)
          controllerMaxValue = prevControllerMaxValue;
        else
          controllerMinValue = prevControllerMinValue;
        
        update();
      }
    }
    else if (state == STATE_SET_LINK && action == MouseEvent.RELEASE)
    {
      // If released on a meter, set the link to that meter
      for (int i = 0; i < meters.length; i++)
      {
        Meter m = meters[i];
        if (m.x <= point.x && point.x < m.x + m.w &&
            m.y <= point.y && point.y < m.y + m.h)
        {
          setMeterLink(i);
          break;
        }
      }
      
      setState(STATE_NORMAL);
    }
  }
  
  protected void setState(int newState)
  {
    state = newState;
    println("Monitor state changed to: " + state);
  }

  public void randomMeterLink()
  {
    setMeterLink((int)p5.random(meters.length));
  }

  public void resetMeterLink()
  {
    setMeterLink(originalMeterIndex);
  }
  
  public void setMeterLink(int meterIndex)
  {
    this.meterIndex = meterIndex;
    meter = meters[meterIndex];
    update();
  }
  
  public void flipOutputRange()
  {
    int tmp = controllerMinValue;
    controllerMinValue = controllerMaxValue;
    controllerMaxValue = tmp;
    update();
  }
  
  public void invertOutputRange()
  {
    controllerMinValue = MAX_CONTROLLER_VALUE - controllerMinValue;
    controllerMaxValue = MAX_CONTROLLER_VALUE - controllerMaxValue;
    update();
  }
  
  public void randomOutputRange()
  {
    controllerMinValue = (int)p5.random(MAX_CONTROLLER_VALUE + 1);
    controllerMaxValue = (int)p5.random(MAX_CONTROLLER_VALUE + 1);
    update();
  }
  
  public void resetOutputRange()
  {
    controllerMinValue = MIN_CONTROLLER_VALUE;
    controllerMaxValue = MAX_CONTROLLER_VALUE;
    update();
  }
}

