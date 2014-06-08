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
 * [F2] toggle monitors display
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
 *
 * 2014-06-06 Fri - v07 subpixel
 * - Allow audio mixer to be chosen (F3 for Microphone, F4 for Stereo Mix)
 * - Show MIDI channel when device not chosen since channel can be changed before device chosen
 */

import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.FloatControl;
import javax.sound.sampled.Line;
import javax.sound.sampled.LineUnavailableException;
import javax.sound.sampled.Mixer;

import ddf.minim.analysis.*;
import ddf.minim.javasound.JSMinim;
import ddf.minim.*;

// Audio analysis
PApplet sketch; // The Processing "sketch" is passed as a fileSystemHandler object to the Minim constructor

Mixer microphoneMixer;
boolean microphoneMixerUsed = false;

Mixer stereoMixer;
boolean stereoMixerUsed = false;

JSMinim jsminim;
Minim minim;
AudioInput linein;
FFT fft;
int minBandwidth = 44; // Bandwidth of first average
int bandsPerOctave = 4; // Number of bands (averages) per octave
int numBands; // Number of bands (averages) calculated

// MIDI IO
MidiManager midiManager;

int inputCCOffset = 0;   // Base offset for MIDI CC input values (to control Monitor ranges)  
int inputNoteOffset = 0; // Base offset for MIDI input note pitches  

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
  sketch = this;
  
  // Display setup
  size(128, 419);
  frameRate(30);
  background(0);
  
  // Check available audio mixers
  jsminim = new JSMinim(this);
  printMixersDetails();
  
  if (microphoneMixer != null)
  {
    String microphoneMixerName = microphoneMixer.getMixerInfo().getName();
    System.out.println("Using microphoneMixer (" + microphoneMixerName + " )");
    jsminim.setInputMixer(microphoneMixer);
  }
  else
  if (stereoMixer != null)
  {
    String stereoMixerName = stereoMixer.getMixerInfo().getName();
    System.out.println("Using stereoMixer (" + stereoMixerName + " )");
    jsminim.setInputMixer(stereoMixer);
  }

  // Audio input
  minim = new Minim(sketch); // Note: passing "jsminim" instead of "sketch" is the magic sauce
  linein = minim.getLineIn(Minim.STEREO, 512, 44100.0f, 16);

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
    int outputControllerNumber = i + 1;
    
    MeterMonitor meterMonitor = meterMonitors[i] =
      new MeterMonitor(this, meters, meterIndex, midiManager, outputControllerNumber);
    meterMonitor.x = x;
    meterMonitor.y = y;
    meterMonitor.w = meterMonitorWidth;
    meterMonitor.h = meterMonitorHeight - 1;
    y += meterMonitorHeight;
  }

  // Set up MIDI input
  midiManager.setInput(0, 5);
  midiManager.setPlug(this, "plugController");
  midiManager.setPlug(this, "plugNote");
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
  final int FN_KEY = 111; // FN_KEY + n = function key n, eg F1 is 112
  
  if (key == CODED) switch(keyCode)
  {
    case UP:    easeDownAmount *= 1.1f;        break; // Easing faster
    case DOWN:  easeDownAmount *= 1.0f / 1.1f; break; // Easing slower
    case LEFT:  break;
    case RIGHT: break;

    case FN_KEY + 1: displayMeters   ^= true; break; // F1
    case FN_KEY + 2: displayMonitors ^= true; break; // F2

    case FN_KEY + 3:
      if (microphoneMixer == null)
      {
        System.out.println("** microphoneMixer not available");
      }
      else if (microphoneMixerUsed)
      {
        System.out.println("** microphoneMixer has been used already (can only be used once)");
      }
      else
      {
        String microphoneMixerName = microphoneMixer.getMixerInfo().getName();
        System.out.println("Using microphoneMixer (" + microphoneMixerName + " )");
        
        // Close/stop Minim objects
        linein.close();
        minim.stop();
        jsminim.stop();

        // Start again
        jsminim = new JSMinim(sketch);
        jsminim.setInputMixer(microphoneMixer);
        
        // Audio input
        minim = new Minim(jsminim); // Note: passing "jsminim" instead of "this" is the magic sauce
        System.out.println("getLineIn...");
        linein = minim.getLineIn(Minim.MONO, 512, 44100.0f, 16);

        // Frequency analysis
        fft = new FFT(linein.bufferSize(), linein.sampleRate());
        fft.logAverages(minBandwidth, bandsPerOctave);
        numBands = fft.avgSize();
        println("Number of averages to be calculated: " + numBands);
        
        microphoneMixerUsed = true;
      }
      break;

    case FN_KEY + 4:
      if (stereoMixer == null)
      {
        System.out.println("** stereoMixer not available");
      }
      else if (stereoMixerUsed)
      {
        System.out.println("** stereoMixer has been used already (can only be used once)");
      }
      else
      {
        String stereoMixerName = stereoMixer.getMixerInfo().getName();
        System.out.println("Using stereoMixer (" + stereoMixerName + " )");

        // Close/stop Minim objects
        linein.close();
        minim.stop();
        jsminim.stop();

        // Start again
        jsminim = new JSMinim(sketch);
        jsminim.setInputMixer(stereoMixer);
        
        // Audio input
        minim = new Minim(jsminim); // Note: passing "jsminim" instead of "this" is the magic sauce
        System.out.println("getLineIn...");
        linein = minim.getLineIn(Minim.STEREO, 512, 44100.0f, 16);

        // Frequency analysis
        fft = new FFT(linein.bufferSize(), linein.sampleRate());
        fft.logAverages(minBandwidth, bandsPerOctave);
        numBands = fft.avgSize();
        println("Number of averages to be calculated: " + numBands);
        
        stereoMixerUsed = true;
      }
      break;

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
    
    case '[': if (inputCCOffset > 0)
              {
                inputCCOffset -= 20;
                inputNoteOffset -= 24;
              }
              println("inputCCOffset: " + inputCCOffset);
              break;

    case ']': if (inputCCOffset < 80)
              {
                inputCCOffset += 20;
                inputNoteOffset += 24;
              }
              println("inputCCOffset: " + inputCCOffset);
              break;

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

    default:
      println("key: " + key);
      break;
  }
}

void plugController(promidi.Controller controller)
{
  print("plugController(): ");
  int num = controller.getNumber();
  int val = controller.getValue();
  println("num: " + num + ", val: " + val);
  
  // Sliders - MAX VALUE
  if (inputCCOffset + 1 <= num && num <= inputCCOffset + 9)
  {
    int monitorIndex = num - (inputCCOffset + 1);
    
    if (monitorIndex < meters.length)
    {
      MeterMonitor monitor = meterMonitors[monitorIndex];
      monitor.setMaxValue(val);
    }
  }
  else
  // Knobs - MIN VALUE
  if (inputCCOffset + 11 <= num && num <= inputCCOffset + 19)
  {
    int monitorIndex = num - (inputCCOffset + 11);
    
    if (monitorIndex < meters.length)
    {
      MeterMonitor monitor = meterMonitors[monitorIndex];
      monitor.setMinValue(val);
    }
  }
  else
  // Transport control buttons
  switch(num)
  {
    // REWIND BUTTON
    case 101: resetMonitorLinks(); break;
    
    // PLAY BUTTON
    case 102: paused ^= true; break;
    
    // FFWD BUTTON
    case 103: resetMonitorRanges(); break;
    
    // LOOP BUTTON
    case 104: randomMonitorLinks(); break;
    
    // STOP BUTTON
    case 105: flipMonitorRanges(); break;

    // RECORD BUTTON
    case 106: randomMonitorRanges(); break;
  }
}

void plugNote(promidi.Note note)
{
  int vel = note.getVelocity();
  int pit = note.getPitch();
  println("vel: " + vel + ", pit: " + pit);

  // Upper row buttons - RANDOM RANGE
  if (vel == 127 && inputNoteOffset + 12 <= pit && pit <= inputNoteOffset + 20)
  {
    int monitorIndex = pit - (inputNoteOffset + 12);
    
    if (monitorIndex < meters.length)
    {
      MeterMonitor monitor = meterMonitors[monitorIndex];
      monitor.randomOutputRange();
    }
  }
  else
  // Lower row buttons - RESET RANGE
  if (inputNoteOffset + 21 <= pit && pit <= inputNoteOffset + 29)
  {
    int monitorIndex = pit - (inputNoteOffset + 21);
    
    if (monitorIndex < meters.length)
    {
      MeterMonitor monitor = meterMonitors[monitorIndex];
      monitor.resetOutputRange();
    }
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
  {
    meterMonitors[i].randomMeterLink();
  }
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
  {
    meterMonitors[i].resetMeterLink();
  }
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
  {
    meterMonitors[i].flipOutputRange();
  }
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
  {
    meterMonitors[i].invertOutputRange();
  }
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
  {
    meterMonitors[i].randomOutputRange();
  }
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
  {
    meterMonitors[i].resetOutputRange();
  }
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


//
// Lifted from http://stackoverflow.com/questions/4211439/getting-the-system-sound-in-java
//
public void printMixersDetails(){
    javax.sound.sampled.Mixer.Info[] mixerInfos = AudioSystem.getMixerInfo();
    System.out.println("There are " + mixerInfos.length + " mixer info objects");
    
    for (int i = 0; i < mixerInfos.length; i++)
    {
        System.out.println("---------------------------------------");
        Mixer.Info mixerInfo = mixerInfos[i];
        String mixerName = mixerInfo.getName();
        
        System.out.println("Mixer [" + i + "]: "+mixerName);
        System.out.println("Description: " + mixerInfo.getDescription());
        
        Mixer mixer = AudioSystem.getMixer(mixerInfo);
        
        if (mixerName.startsWith("Microphone") && microphoneMixer == null)
        {
          System.out.println("** Setting microphoneMixer");
          microphoneMixer = mixer;
        }
        
        if (mixerName.startsWith("Stereo Mix") && stereoMixer == null)
        {
          System.out.println("** Setting stereoMixer...");
          stereoMixer = mixer;
        }
        
        Line.Info[] lineinfos = mixer.getTargetLineInfo();
        for (Line.Info lineinfo : lineinfos)
        {
            System.out.println("line:" + lineinfo);
            try
            {
                Line line = mixer.getLine(lineinfo);
                line.open();
                if(line.isControlSupported(FloatControl.Type.VOLUME))
                {
                    FloatControl volumeControl = (FloatControl) line.getControl(FloatControl.Type.VOLUME);
                    float volumeValue = volumeControl.getValue();
                    System.out.println("Volume:"+volumeValue);
                    
                    //JProgressBar pb = new JProgressBar();
                    //// if you want to set the value for the volume 0.5 will be 50%
                    //// 0.0 being 0%
                    //// 1.0 being 100%
                    ////control.setValue((float) 0.5);
                    //int value = (int) (volumeValue()*100);
                    //pb.setValue(value);
                    //j.add(new JLabel(lineinfo.toString()));
                    //j.add(pb);
                    //j.pack();
                }
                
                line.close();
            }
            catch (LineUnavailableException e)
            {
                e.printStackTrace();
            }
        }
    }
}

