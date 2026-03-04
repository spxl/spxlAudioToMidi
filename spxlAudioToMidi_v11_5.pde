/**
 * spxlAudioToMidi
 * 2010-06-23 by subpixel
 * http://subpixels.com
 *
 * Audio reactive (using minim.getLineIn)
 * - For "Stereo Mix" monitoring in WIndows 10, see https://mediarealm.com.au/articles/stereo-mix-setup-windows-10/
 * - "CABLE Output" mixer name for VB-CABLE Virtual Audio Device; see https://vb-audio.com/Cable/index.htm
 * - "VoiceMeeter Output", "VoiceMeeter Aux Output", "VoiceMeeter VAIO3 Output" for VoiceMeeter Potato;
 *   see https://vb-audio.com/Voicemeeter/potato.htm
 *
 * Controls:
 *
 * Where upper and lower case commands are available for "montor/s":
 * - the lower case version is for ALL mintors
 * - the upper case version is for the SINGLE monitor at the mouse position.
 *
 * [p/space] toggle pause
 * [m] toggle mute on/off
 * [M] mute shot (short burst followed by mute)
 * [o] toggle MIDI output mute on/off
 *
 * [E] toggle easing on/off
 * [e] reset easing value (and turn easing on)
 * [up] increase falloff speed
 * [down] decrease falloff speed
 * [z] reset meter level/s
 *
 * [q/Q] randomise link for monitor/s
 * [a/A] reset link to default for monitor/s
 *
 * [f/F] flip min, max for monitor/s
 * [v/V] invert range for monitor/s
 * [r/R] random range for monitor/s
 * [s/S] reset range for monitor/s
 * [u/U] random upper range for monitor/s
 * [y/Y] reset upper range for monitor/s
 * [l/L] random lower range for monitor/s
 * [k/K] reset lower range for monitor/s
 *
 * [1/2/3/../9/0] set output MIDI channel
 * [!/@/#/../(/)] set input MIDI channel
 *
 * [h] toggle hex/decimal value display
 *
 * [F1] toggle meters display
 * [F2] toggle monitors display
 * [F3] Analyse microphone input (defunct)
 * [F4] Analyse selected audio mixer
 * [F5] Reload mixer preferences (and re-select first available preference)
 *
 * [[] Decrease expected CC numbers (by 20) and note pitches (by 2 octaves) for MIDI input
 * []] Increase expected CC numbers (by 20) and note pitches (by 2 octaves) for MIDI input
 *
 * CHANGES
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
 * - Implement MIDI input to control meter monitors
 *
 * 2014-06-08 Sun - v08 subpixel
 * - Rejig MidiManager menu system:
 *    Channel and device shown on one line
 *    MIDI input and MIDI output selectable
 *    Click channel number to get channel menu, click device name to get device menu
 *
 * 2014-06-09 Mon - v09 subpixel
 * - MeterMonitor.displayInfo() for value changes / messages (especially helpful for MIDI control)
 * - New muteShot() command (key 'M')
 *
 * 2016-09-08 Thu - v10 subpixel
 * - Random ('u', 'l') & reset ('y', 'k') upper & lower range commands for meters
 * - Reset meter levels key changed to 'z' (from 'l')
 * - Flipped upper/lowercase keyboard commands for single/all Monitor changes
 *
 * 2020-10-05 Mon - v11 subpixel
 * - Change MIDI library from ProMidi (no loger supported) to MidiBus
 * - TODO: MIDI input handling
 * - Change frameRate(30) to frameRate(60) (also update spxlMeter algorithm and constants)
 * - Update Minim input audio mixer handling (ditched JSminim stuff, based on Advanced/setInputMixer example)
 *    - Now handles repeated switching between "Microphone" "Stereo Mix" / "CABLE Output"
 * - Extract from setup(): setupMeters(), setupInputMixers()
 * - Extract common functionality setupAudioAnalysis() for use in setup() and keyPressed()
 * - Rename linein to audioInput
 * - Replace p5.println() with System.out.println()
 *
 * 2020-10-09 Fri - v11.1 subpixel
 * - Pass raw (not eased) FFT value to meter.update(value) and allow the meter to eaase its output
 *
 * 2020-12-12 Sat - v11.3 subpixel
 * - setupInputMixers(): Use strings from "mixer-prefs.txt" to choose stereo mixer
 *
 * 2021-08-17 Tue - v11.4 subpixel
 * - setupInputMixers(): Stop searching if microphone mixer found and first preference mixer found
 *
 * 2022-09-13 Mon - v11.5 subpixel
 * - Add spxlMidiManager.outputMuted (key 'o')
 * - Add class MixerManager: handles list of mixers; display mixer-prefs list and (unselectable) other mixers
 * - Introduce class SimpleLock, object menuLock: resolve mouseEvent() clashes (MeterMonitor, MidiiManager, MixerManager) 
 * - FN_KEY + 4: always setup the selected mixer (including setting to null, and reset meter levels)
 * - Add try/catch for minim.getLineIn() to fail gracefully instead of crashing (eg on unsupported sample rate, bit depth)
 * - Add FN_KEY + 5 to rerun MixerManager.setupMixers(); pops the selection list if another menu not open
 * - FN_KEY + 3 to select microphone input now redundant; mic mixer name instead specified in the MIXER_PREFS_FILENAME file
 */

// Audio mixers
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.Mixer;

// Audio analysis
import ddf.minim.analysis.*;
import ddf.minim.*;

PApplet sketch; // The Processing "sketch" is passed as a fileSystemHandler object to the Minim constructor

SimpleLock menuLock = new SimpleLock();

// MIDI IO
MidiManager midiManager;

int inputCCOffset = 0;   // Base offset for MIDI CC input values (to control Monitor ranges)  
int inputNoteOffset = 0; // Base offset for MIDI input note pitches  

// Mixer manager
MixerManager mixerManager;

// Mixer determined to be a microphone
Mixer microphoneMixer;
boolean microphoneMixerUsed = false;

// Mixer determined to be the "Stereo Mix" or "CABLE Output"
Mixer stereoMixer;
boolean stereoMixerUsed = false;

Mixer selectedMixer;
String selectedMixerName = "NONE";

Minim minim;
AudioInput audioInput;
FFT fft;
int minBandwidth = 44; // Bandwidth of first average
int bandsPerOctave = 4; // Number of bands (averages) per octave
int numBands; // Number of bands (averages) calculated

// Meters
final int numMeters = 30; // Number of meters to display
Meter[] meters;
int meterWidth = 32;
int meterSpacing;

// Meter Monitors
final int numMeterMonitors = 10;
MeterMonitor[] meterMonitors;
int meterMonitorWidth = 64;
int meterMonitorSpacing;

// User controls
boolean paused = false;
boolean muted = false;

// "Mute shot" - after a number of updates, mute
final int NUM_MUTE_SHOT_UPDATES = 4;
int muteShotCounter = 0; // Countdown to muted

boolean displayHex = false;
boolean displayMeters = true;
boolean displayMonitors = true;

boolean easeDown = true;
float easeDownAmount = 0.1f;

void setup()
{
  sketch = this; // Note: "this" is the PApplet object
  
  // Display setup
  size(128, 433);
  frameRate(60);
  background(0);
  
  // Enable graphics smoothing
  smooth();
  
  int x = 0;
  int y = 0;
    
  // MIDI Manager
  midiManager = new MidiManager(sketch, menuLock, x, y);
  y += midiManager.h;
  
  // Callback to set up MIDI input when the input device is changed
  midiManager.setPlugSetup(sketch, "plugSetup");

  // Mixer Manager
  mixerManager = new MixerManager(sketch, menuLock, x, y);
  y += mixerManager.h;
  
  stereoMixer = mixerManager.getMixer();
  
  // Set up band meters and meter monitors
  setupMeters(x, y + 1);

  System.out.println("\nSelecting audio input mixer");
  Mixer mixer = null;
  
  // Enable this is you want to specifically autoselect a mixer
  // If no mixer specified, the default system recording decide will be used
  if (stereoMixer != null)
  {
    mixer = stereoMixer;
  }
  else if (microphoneMixer != null)
  {
    mixer = microphoneMixer;
  }
  else
  {
    System.out.println("** Input mixer not set");
  }
  
  // Set up audio input and frequency analysis
  setupAudioAnalysis(mixer);
}

//TODO: MidiBus MIDI input handling
//void plugSetup()
//{
//  // Set up MIDI input plugs
//  midiManager.setPlug(sketch, "plugController");
//  midiManager.setPlug(sketch, "plugNote");
//}

void draw()
{
  // UPDATE PHASE
  
  // Process audio
  if (fft != null && audioInput != null)
  {
    fft.forward(audioInput.mix);
  }

  // Update and audio level meters and meter monitors (if not paused)
  if (!paused)
  {
    for (int i = 0; i < numMeters && i < numBands; i++)
    {
      float value = muted ? 0f : fft.getAvg(i);      
      meters[i].update(value);
    }
    
    for (int i = 0; i < numMeterMonitors; i++)
    {
      meterMonitors[i].update();
      meterMonitors[i].outputMidiControl();      
    }
  }

  // DRAW PHASE
  
  background(0);

  // Update and draw audio level meters
  if (displayMeters)
  {
    for (int i = 0; i < numMeters && i < numBands; i++)
    {
      meters[i].draw();
    }
  }
  
  // Draw meter monitors
  if (displayMonitors)
  {
    for (int i = 0; i < numMeterMonitors; i++)
    {
      meterMonitors[i].draw();
    }
  }
  
  // Draw MIDI manager
  midiManager.draw();
  
  // Draw mixer manager
  mixerManager.draw();
  
  // Display state information
  
  {
    int x = width / 8;
    int y = midiManager.h + midiManager.textHeight;
    int w = width - x * 2;
    int h = midiManager.textHeight;

    fill(255, 255, 0);
    
    if (paused)
    {
      fill(0, 0, 128, 192);
      rect(x, y, w, h);
      
      y += h;

      fill(255, 255, 0);
      text("PAUSED", x, y - 2);
    }
    
    if (muted)
    {
      fill(0, 0, 128, 192);
      rect(x, y, w, h);
      
      y += h;

      fill(255, 255, 0);
      text("MUTED", x, y - 2);
    }
  }

  // Countdown to mute (for "mute shot")
  if (muteShotCounter > 0)
  {
    muteShotCounter--;
    
    if (muteShotCounter <= 0)
    {
      muted = true;
    }
  }
  
  // Free the menu lock, if ready to unlock
  menuLock.unlockIfReady();
}

void stop()
{
  // always close Minim audio classes when you are finished with them
  if (audioInput != null)
  {
    audioInput.close();
  }
  
  // always stop Minim before exiting
  if (minim != null)
  {
    minim.stop();
  }
  
  // this closes the sketch
  super.stop();
}

void keyPressed()
{
  final int FN_KEY = 111; // FN_KEY + n = function key n, eg F1 is 112
  
  if (key == CODED) switch(keyCode)
  {
    case UP:
      // Easing faster
      easeDownAmount *= 1.1f;
      if (easeDownAmount > 1f)
      {
        easeDownAmount = 1f;
      }
      break;
      
    case DOWN:
      // Easing slower
      easeDownAmount *= 1.0f / 1.1f;
      break;
      
    case LEFT:  break;
    case RIGHT: break;

    case FN_KEY + 1: displayMeters   ^= true; break; // F1
    case FN_KEY + 2: displayMonitors ^= true; break; // F2

    case FN_KEY + 3:
      if (microphoneMixer == null)
      {
        System.out.println("\n** microphoneMixer not available\n");
      }
      //else
      {
        setupAudioAnalysis(microphoneMixer);
      }
      break;

    case FN_KEY + 4:
      stereoMixer = mixerManager.getMixer();
      
      if (stereoMixer == null)
      {
        System.out.println("\n** stereoMixer not available\n");
      }
      
      setupAudioAnalysis(stereoMixer);
      break;

    case FN_KEY + 5:
      mixerManager.setupMixers();
      
      // Pop up the mixer selection menu if the interface is not locked by another menu
      if (!menuLock.isLockedByOther(mixerManager))
      {
        mixerManager.setState(MixerManager.SELECTING_MIXER);
      }

      break;
    
    default:
      System.out.println("keyCode: " + keyCode);
      break;
  }
  else switch(key)
  {
    case ' ': paused ^= true; break; // Toggle paused

    case '[': if (inputCCOffset > 0)
              {
                inputCCOffset -= 20;
                inputNoteOffset -= 24;
              }
              System.out.println("inputCCOffset: " + inputCCOffset);
              break;

    case ']': if (inputCCOffset < 80)
              {
                inputCCOffset += 20;
                inputNoteOffset += 24;
              }
              System.out.println("inputCCOffset: " + inputCCOffset);
              break;

    case 'a': resetMonitorLinks();  break;
    case 'A': resetMonitorLink();   break;

    case 'e': easeDownAmount = 0.1f; // Reset ease amount
              easeDown = true;
              break;
    case 'E': easeDown ^= true; break; // Toggle easing

    case 'f': flipMonitorRanges();   break;
    case 'F': flipMonitorRange();    break;

    case 'h': displayHex ^= true; break; // Used in MeterMonitor class

    case 'k': resetMonitorMinValues(); break;
    case 'K': resetMonitorMinValue();  break;
    
    case 'l': randomMonitorMinValues(); break;
    case 'L': randomMonitorMinValue();  break;

    case 'm': muted ^= true; break; // Toggle mute
    case 'M': muteShot(); break;

    case 'o': midiManager.outputMuted ^= true; break; // Toggle MIDI output muted
    
    case 'q': randomMonitorLinks(); break;
    case 'Q': randomMonitorLink();  break;

    case 'r': randomMonitorRanges(); break;
    case 'R': randomMonitorRange();  break;

    case 's': resetMonitorRanges();  break;
    case 'S': resetMonitorRange();   break;

    case 'u': randomMonitorMaxValues(); break;
    case 'U': randomMonitorMaxValue();  break;

    case 'y': resetMonitorMaxValues(); break;
    case 'Y': resetMonitorMaxValue();  break;

    case 'v': invertMonitorRanges(); break;
    case 'V': invertMonitorRange();  break;
    
    case 'z': resetMeterLevels();   break;
    
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
    
    case '!': midiManager.setInputChannel(0); break;
    case '@': midiManager.setInputChannel(1); break;
    case '#': midiManager.setInputChannel(2); break;
    case '$': midiManager.setInputChannel(3); break;
    case '%': midiManager.setInputChannel(4); break;
    case '^': midiManager.setInputChannel(5); break;
    case '&': midiManager.setInputChannel(6); break;
    case '*': midiManager.setInputChannel(7); break;
    case '(': midiManager.setInputChannel(8); break;
    case ')': midiManager.setInputChannel(9); break;

    default:
      System.out.println("key: " + key);
      break;
  }
}

//TODO: MidiBus MIDI input handling
//void plugController(promidi.Controller controller)
//{
//  print("plugController(): ");
//  int ccNumber = controller.getNumber();
//  int ccValue = controller.getValue();
//  System.out.println("ccNumber: " + ccNumber + ", ccValue: " + ccValue);
  
//  // For some reason, proMIDI interprets a CC message with value 0 as a NOTE with the CC number
//  // for the pitch and 0 for the velocity. This is very annoying.
//  if (ccValue == 1)
//  {
//    ccValue = 0;
//    System.out.println("  Mapped ccValue to: " + ccValue);
//  }
  
//  // Sliders: MAX VALUE
//  if (inputCCOffset + 1 <= ccNumber && ccNumber <= inputCCOffset + 9)
//  {
//    int monitorIndex = ccNumber - (inputCCOffset + 1);
    
//    if (monitorIndex < meterMonitors.length)
//    {
//      MeterMonitor monitor = meterMonitors[monitorIndex];
//      monitor.setMaxValue(ccValue);
//    }
//  }
//  else
//  // Knobs: MIN VALUE
//  if (inputCCOffset + 11 <= ccNumber && ccNumber <= inputCCOffset + 19)
//  {
//    int monitorIndex = ccNumber - (inputCCOffset + 11);
    
//    if (monitorIndex < meterMonitors.length)
//    {
//      MeterMonitor monitor = meterMonitors[monitorIndex];
//      monitor.setMinValue(ccValue);
//    }
//  }
//  else
//  // Transport control buttons
//  switch(ccNumber)
//  {
//    // REWIND BUTTON
//    case 101: resetMonitorLinks(); break;
    
//    // PLAY BUTTON
//    case 102: paused ^= true; break;
    
//    // FFWD BUTTON
//    case 103: resetMonitorRanges(); break;
    
//    // LOOP BUTTON
//    case 104: randomMonitorLinks(); break;
    
//    // STOP BUTTON
//    case 105: flipMonitorRanges(); break;

//    // RECORD BUTTON
//    case 106: randomMonitorRanges(); break;
//  }
//}

//TODO: MidiBus MIDI input handling
//void plugNote(promidi.Note note)
//{
//  int velocity = note.getVelocity();
//  int pitch = note.getPitch();
//  System.out.println("velocity: " + velocity + ", pitch: " + pitch);

//  // Upper row buttons - RANDOM RANGE
//  if (velocity > 64 && inputNoteOffset + 12 <= pitch && pitch <= inputNoteOffset + 20)
//  {
//    int monitorIndex = pitch - (inputNoteOffset + 12);
    
//    if (monitorIndex < meters.length)
//    {
//      MeterMonitor monitor = meterMonitors[monitorIndex];
//      monitor.randomOutputRange();
//    }
//  }
//  else
//  // Lower row buttons - RESET RANGE
//  if (velocity > 64 && inputNoteOffset + 21 <= pitch && pitch <= inputNoteOffset + 29)
//  {
//    int monitorIndex = pitch - (inputNoteOffset + 21);
    
//    if (monitorIndex < meters.length)
//    {
//      MeterMonitor monitor = meterMonitors[monitorIndex];
//      monitor.resetOutputRange();
//    }
//  }
//}

void muteShot()
{
  // Initialise countdown to mute (and unmute now)
  muteShotCounter = NUM_MUTE_SHOT_UPDATES;
  muted = false;
}

void setupMeters(int ox, int oy)
{
  int x = ox;
  int y = oy;
  
  // Set up band meters
  meters = new Meter[numMeters];
  meterSpacing = (height - y) / numMeters;
  
  for (int i = 0; i < numMeters; i++)
  {
    Meter meter = meters[i] = new Meter(sketch);
    meter.x = x;
    meter.y = y;
    meter.w = meterWidth;
    meter.h = meterSpacing - 1;
    y += meterSpacing;
  }

  // Set up the meter monitors
  meterMonitors = new MeterMonitor[numMeterMonitors];
  meterMonitorSpacing = meterSpacing * numMeters / numMeterMonitors;
  x = width - meterMonitorWidth; // Place monitors to the right of meters
  y = oy;
  
  for (int i = 0; i < numMeterMonitors; i++)
  {
    int meterIndex = numMeters * i / numMeterMonitors;
    int outputControllerNumber = i + 1;
    
    MeterMonitor meterMonitor = meterMonitors[i] =
      new MeterMonitor(sketch, menuLock, meters, meterIndex, midiManager, outputControllerNumber);
      
    meterMonitor.x = x;
    meterMonitor.y = y;
    meterMonitor.w = meterMonitorWidth;
    meterMonitor.h = meterMonitorSpacing - 1;
    y += meterMonitorSpacing;
  }
}

void resetMeterLevels()
{
  for (int i = 0; i < meters.length; i++)
  {
    meters[i].reset();
  }
  
  System.out.println("** Meter levels reset");
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

void randomMonitorMinValue()
{
  MeterMonitor m = monitorAtMouse();
  if (m != null)
  {
    m.randomOutputMinValue();
    return;
  }
}
  
void randomMonitorMinValues()
{
  for (int i = 0; i < meterMonitors.length; i++)
  {
    meterMonitors[i].randomOutputMinValue();
  }
}

void resetMonitorMinValue()
{
  MeterMonitor m = monitorAtMouse();
  if (m != null)
  {
    m.resetOutputMinValue();
    return;
  }
}
  
void resetMonitorMinValues()
{
  for (int i = 0; i < meterMonitors.length; i++)
  {
    meterMonitors[i].resetOutputMinValue();
  }
}

void randomMonitorMaxValue()
{
  MeterMonitor m = monitorAtMouse();
  if (m != null)
  {
    m.randomOutputMaxValue();
    return;
  }
}
  
void randomMonitorMaxValues()
{
  for (int i = 0; i < meterMonitors.length; i++)
  {
    meterMonitors[i].randomOutputMaxValue();
  }
}

void resetMonitorMaxValue()
{
  MeterMonitor m = monitorAtMouse();
  if (m != null)
  {
    m.resetOutputMaxValue();
    return;
  }
}
  
void resetMonitorMaxValues()
{
  for (int i = 0; i < meterMonitors.length; i++)
  {
    meterMonitors[i].resetOutputMaxValue();
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

void setupAudioAnalysis(Mixer mixer)
{
  // Audio analysis setup
  minim = new Minim(sketch);
  
  boolean changedMixer = false;
  
  if (mixer != selectedMixer)
  {
    if (audioInput != null)
    {
      System.out.println("** Closing audio input [" + selectedMixerName + "]");
      audioInput.close();
      audioInput = null;
    }
  
    selectedMixer = mixer;
    
    if (selectedMixer != null)
    {
      selectedMixerName = selectedMixer.getMixerInfo().getName();
      System.out.println("** Setting input mixer [" + selectedMixerName + "]");
      minim.setInputMixer(selectedMixer);
      changedMixer = true;
    }
  }
  
  if (changedMixer || audioInput == null)
  {
    System.out.println("** Opening audioInput [" + selectedMixerName + "]");
    AudioInput newAudioInput = null;

    try
    {
      newAudioInput = minim.getLineIn(Minim.MONO, 512, 44100.0f, 16);
    }
    catch (Exception e)
    {
      String message = e.getMessage();
      System.out.println("** minim.getLineIn() exception: " + message);
    }

    if (newAudioInput == null)
    {
      selectedMixerName = "!" + selectedMixerName;
    }
    else
    {
      audioInput = newAudioInput;
      
      // Frequency analysis
      fft = new FFT(audioInput.bufferSize(), audioInput.sampleRate());
      fft.logAverages(minBandwidth, bandsPerOctave);
      numBands = fft.avgSize();
      System.out.println("Number of averages to be calculated: " + numBands);
    }
  }
  else
  {
    System.out.println("** Already using audioInput [" + selectedMixerName + "]");
  }
  
  resetMeterLevels();
}
