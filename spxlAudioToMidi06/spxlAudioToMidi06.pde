/**
 * spxlAudioToMidi
 * 2010-06-23 by subpixel
 * http://subpixels.com
 *
 * Audio reactive (using minim.getLineIn)
 * Likely will not react to audio as an applet
 *
 * Controls:
 *
 * [1/2/3/../9/0] set output MIDI channel
 * [!/@/#/../(/)] set output MIDI device
 * [p/space] toggle pause
 * [m] toggle mute on/off
 * [l] reset meter levels
 *
 * [E] toggle easing on/off
 * [e] reset easing value (and turn easing on)
 * [up] increase snappiness of easing
 * [down] decrease snappiness of easing
 *
 * [q/Q] randomise link for monitor/s
 * [a/A] reset link to default for monitor/s
 *
 * [f/F] flip min, max for monitor/s
 * [v/V] invert range for monitor/s
 * [r/R] random range for monitor/s
 * [s/S] reset range for monitor/s
 *
 * [F1] toggle meters display
 * [F2] toggle monitos display
 * [h] toggle hex/decimal value display
 *
 * 2010-06-19 Sat - subpixel
 * - Created
 *
 * 2010-06-23 Wed - subpixel
 * - Use logAverages() instead of linAverages()
 * - Use ProMIDI to output MIDI data
 *
 * 2010-06-24 Thu - v03 subpixel
 * - MeterMonitors to replace "videos"
 *
 * 2010-06-25 Fri - v04 subpixel
 * - MidiManager to encapsulate MIDI IO and allow selection of output device
 *
 * 2010-06-27 Sun - v05 subpixel
 * - Use Midi input to control monitor parameters
 * - INCOMPLETE
 *
 * 2013-08-13 Tue - v06 subpixel
 * - MouseEvent changes for Processing 2.0 in spxlMeterMonitor, spxlMidiManager
 * - Rename "in" to "linein" for descriptiveness
 * - Update key controls for easing (up/down to adjust amount, e reset, E toggle)
 * 2013-08-14 Wed - v06 subpixel
 * - Remove dependency on java.awt.Point (use PVector instead)
 */

import ddf.minim.analysis.*;
import ddf.minim.*;

// Audio analysis
Minim minim;
AudioInput linein;
FFT fft;
int minBandwidth = 44; // Bandwidth of first average
int bandsPerOctave = 4; // Number of bands (averages) per octave
int numBands; // Number of bands (averages) calculated

// MIDI IO
MidiManager midiManager;

// Meters
final int numMeters = 30; // Number of meters to display
Meter[] meters;
int meterWidth = 32;
int meterHeight;

// Meter Monitors
final int numMeterMonitors = 10;
MeterMonitor[] meterMonitors;
int meterMonitorWidth = 64;
int meterMonitorHeight;

// User controls
boolean paused = false;
boolean muted = false;
boolean displayHex = false;
boolean displayMeters = true;
boolean displayMonitors = true;

boolean easeDown = true;
float easeDownAmount = 0.1f;

void setup()
{
  // Display setup
  size(128, 419);
  frameRate(30);
  background(0);

  // Audio input
  minim = new Minim(this);
  linein = minim.getLineIn(Minim.STEREO, 512);

  // Frequency analysis
  fft = new FFT(linein.bufferSize(), linein.sampleRate());
  fft.logAverages(minBandwidth, bandsPerOctave);
  numBands = fft.avgSize();
  println("Number of averages to be calculated: " + numBands);
  
  // MIDI IO
  midiManager = new MidiManager(this);

  // Set up band meters
  meters = new Meter[numMeters];
  int x = 0;
  int y = midiManager.h + 1;
  meterHeight = (height - y) / numMeters;
  
  for (int i = 0; i < numMeters; i++)
  {
    Meter meter = meters[i] = new Meter(this);
    meter.x = x;
    meter.y = y;
    meter.w = meterWidth;
    meter.h = meterHeight - 1;
    y += meterHeight;
  }
  
  // Set up the meter monitors
  meterMonitors = new MeterMonitor[numMeterMonitors];
  meterMonitorHeight = meterHeight * 2;
  x = width - meterMonitorWidth; // Place monitors to the right of meters
  y = midiManager.h + 1;
  meterMonitorHeight = meterHeight * numMeters / numMeterMonitors;
  
  for (int i = 0; i < numMeterMonitors; i++)
  {
    int meterIndex = numMeters * i / numMeterMonitors;
    int controllerNumber = i + 1;
    
    MeterMonitor meterMonitor = meterMonitors[i] =
      new MeterMonitor(this, meters, meterIndex, midiManager, controllerNumber);
    meterMonitor.x = x;
    meterMonitor.y = y;
    meterMonitor.w = meterMonitorWidth;
    meterMonitor.h = meterMonitorHeight - 1;
    y += meterMonitorHeight;
  }
}

void draw()
{
  fft.forward(linein.mix);

  background(0);

  // Update and draw audio level meters
  for (int i = 0; i < numMeters && i < numBands; i++)
  {
    Meter meter = meters[i];

    // Update values if not paused    
    if (!paused)
    {
      float value = muted ? 0f : fft.getAvg(i);
      
      // Jump up to higher value, ease down to lower value
      if (easeDown)
        value = max(value, lerp(meter.value, value, easeDownAmount));

      meter.update(value);
    }
    
    if (displayMeters)
      meter.draw();
  }
  
  // Update and draw meter monitors (and output MIDI control)
  for (int i = 0; i < numMeterMonitors; i++)
  {
    MeterMonitor meterMonitor = meterMonitors[i];
    
    meterMonitor.update();
    
    if (displayMonitors)
      meterMonitor.draw();
  }
  
  // Draw Midi Manager
  midiManager.draw();
  
  if (paused || muted)
  {
    int x = width / 8;
    int y = midiManager.h + midiManager.textHeight;
    int w = width - x * 2;
    int h = midiManager.textHeight * 2;

    fill(0, 0, 128, 192);
    rect(x, y, w, h);

    x += 2;
    y += midiManager.textHeight + midiManager.textOffsetY;

    fill(255, 255, 0);
    
    if (paused)
      text("PAUSED", x, y);
    
    if (muted)
      text("MUTED", x, y + midiManager.textHeight);
  }
}

void stop()
{
  // always close Minim audio classes when you are finished with them
  linein.close();
  // always stop Minim before exiting
  minim.stop();
  // this closes the sketch
  super.stop();
}

void keyPressed()
{
  if (key == CODED) switch(keyCode)
  {
    case UP:    easeDownAmount *= 1.1f;        break; // Easing faster
    case DOWN:  easeDownAmount *= 1.0f / 1.1f; break; // Easing slower
    case LEFT:  break;
    case RIGHT: break;
    case 112: displayMeters   ^= true; break; // F1
    case 113: displayMonitors ^= true; break; // F2
    default:
      println("keyCode: " + keyCode);
      break;
  }
  else switch(key)
  {
    case 'p':
    case ' ': paused          ^= true; break;
    case 'm': muted           ^= true; break;
    case 'e': easeDownAmount   = 0.1f; // Reset ease amount
              easeDown         = true;
              break;
    case 'E': easeDown        ^= true; break; // Toggle easing
    case 'h': displayHex      ^= true; break;

    case 'l': resetMeterLevels();   break;

    case 'q': randomMonitorLink();  break;
    case 'Q': randomMonitorLinks(); break;
    case 'a': resetMonitorLink();   break;
    case 'A': resetMonitorLinks();  break;

    case 'f': flipMonitorRange();    break;
    case 'F': flipMonitorRanges();   break;
    case 'v': invertMonitorRange();  break;
    case 'V': invertMonitorRanges(); break;
    case 'r': randomMonitorRange();  break;
    case 'R': randomMonitorRanges(); break;

    case 's': resetMonitorRange();   break;
    case 'S': resetMonitorRanges();  break;
    
    case '1': midiManager.setOutputChannel(0); break;
    case '2': midiManager.setOutputChannel(1); break;
    case '3': midiManager.setOutputChannel(2); break;
    case '4': midiManager.setOutputChannel(3); break;
    case '5': midiManager.setOutputChannel(4); break;
    case '6': midiManager.setOutputChannel(5); break;
    case '7': midiManager.setOutputChannel(6); break;
    case '8': midiManager.setOutputChannel(7); break;
    case '9': midiManager.setOutputChannel(8); break;
    case '0': midiManager.setOutputChannel(9); break;
    
    case '!': midiManager.setOutputDevice(0); break;
    case '@': midiManager.setOutputDevice(1); break;
    case '#': midiManager.setOutputDevice(2); break;
    case '$': midiManager.setOutputDevice(3); break;
    case '%': midiManager.setOutputDevice(4); break;
    case '^': midiManager.setOutputDevice(5); break;
    case '&': midiManager.setOutputDevice(6); break;
    case '*': midiManager.setOutputDevice(7); break;
    case '(': midiManager.setOutputDevice(8); break;
    case ')': midiManager.setOutputDevice(9); break;
  }
}

void resetMeterLevels()
{
  for (int i = 0; i < meters.length; i++)
  {
    meters[i].reset();
  }
}

void randomMonitorLink()
{
  MeterMonitor m = monitorAtMouse();
  if (m != null)
  {
    m.randomMeterLink();
    return;
  }
}
  
void randomMonitorLinks()
{
  for (int i = 0; i < meterMonitors.length; i++)
    meterMonitors[i].randomMeterLink();
}

void resetMonitorLink()
{
  MeterMonitor m = monitorAtMouse();
  if (m != null)
  {
    m.resetMeterLink();
    return;
  }
}
  
void resetMonitorLinks()
{
  for (int i = 0; i < meterMonitors.length; i++)
    meterMonitors[i].resetMeterLink();
}

void flipMonitorRange()
{
  MeterMonitor m = monitorAtMouse();
  if (m != null)
  {
    m.flipOutputRange();
    return;
  }
}

void flipMonitorRanges()
{
  for (int i = 0; i < meterMonitors.length; i++)
    meterMonitors[i].flipOutputRange();
}

void invertMonitorRange()
{
  MeterMonitor m = monitorAtMouse();
  if (m != null)
  {
    m.invertOutputRange();
    return;
  }
}

void invertMonitorRanges()
{
  for (int i = 0; i < meterMonitors.length; i++)
    meterMonitors[i].invertOutputRange();
}

void randomMonitorRange()
{
  MeterMonitor m = monitorAtMouse();
  if (m != null)
  {
    m.randomOutputRange();
    return;
  }
}
  
void randomMonitorRanges()
{
  for (int i = 0; i < meterMonitors.length; i++)
    meterMonitors[i].randomOutputRange();
}

void resetMonitorRange()
{
  MeterMonitor m = monitorAtMouse();
  if (m != null)
  {
    m.resetOutputRange();
    return;
  }
}

void resetMonitorRanges()
{
  for (int i = 0; i < meterMonitors.length; i++)
    meterMonitors[i].resetOutputRange();
}

MeterMonitor monitorAtMouse()
{
  for (int i = 0; i < meterMonitors.length; i++)
  {
    MeterMonitor m = meterMonitors[i];
    if (m.isMouseOver())
    {
      return m;
    }
  }
  
  return null;
}
