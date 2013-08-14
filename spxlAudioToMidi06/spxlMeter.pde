/**
 * spxlMeter.pde
 * 2010-06-19 by subpixel
 * http://subpixels.com
 *
 * An auto-levelling meter class
 *
 * - Keep track of the highest input value.
 * - The output "position" (between 0 and 1) is the current value
 *   divided by the the (current) max value.
 * - The max value decays over time, so if the range of input values
 *   decreases (generally), the output position is still able to
 *   show high peaks.
 *
 * 2010-06-19 Sat - v01 subpixel
 * - Created
 */

public class Meter
{
  protected static final float RESET_MAX_VALUE = 0.001f;
  protected static final float MAX_VALUE_DECAY = 0.996f;

  // Parent PApplet
  protected PApplet p5;

  // Current value
  float value  = 0f;

  // Largest input value seen so far (decays to zero over time)
  float maxValue = RESET_MAX_VALUE;
  
  // Output position, based on current value and maxValue
  float position = 0f;
  
  // Display position, width, height
  int x;
  int y;
  int w = 100;
  int h = 10;

  // Constructor
  public Meter(PApplet p5)
  {
    this(p5, RESET_MAX_VALUE);
  }

  // Constructor, set initial maxValue
  public Meter(PApplet p5, float initialMaxValue)
  {
    this.p5 = p5;
    this.maxValue = initialMaxValue;
  }
  
  public void draw()
  {
    p5.pushStyle();

    // Solid background
    p5.noStroke();
    p5.fill(50);
    p5.rect(x, y, w, h);
    
    // Output position
    int pw = (int)(position * (w - 1));

    p5.fill(50 + position * 206, 50, 150 - position * 255);
    p5.rect(x, y + 2, pw, h - 4);

    p5.stroke(255);
    p5.line(x + pw, y + 2, x + pw, y + h - 3);
    
    p5.popStyle();
  }

  // Update the current meter value
  // (also updates the auto-levelling data and output position)
  public void update(float value)
  {
    this.value = value;
    if (value > maxValue) maxValue = value;
    position = value / maxValue;
    maxValue *= MAX_VALUE_DECAY;
  }

  // Reset the meter value (to zero) and auto-levelling parameters  
  public void reset()
  {
    value = 0f;
    maxValue = RESET_MAX_VALUE;
    float position = 0;
  }
}

