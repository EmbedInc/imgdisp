{   Coordinate transformations.
}
module idisp_xform;
define xform_wind_image;
define xform_image_wind;
%include 'idisp.ins.pas';
{
********************************************************************************
*
*   Subroutine XFORM_WIND_IMAGE (WX, WY, IX, IY)
*
*   Convert the window coordinates WX,WY to the image pixel coordinates IX,IY.
}
procedure xform_wind_image (           {transform window to image coordinates}
  in      wx, wy: sys_int_machine_t;   {input window coordinates}
  out     ix, iy: sys_int_machine_t);  {output image coordinates}
  val_param;

begin
  ix := (wx - uli_x) div zoom;
  iy := (wy - uli_y) div zoom;
  end;
{
********************************************************************************
*
*   Subroutine XFORM_IMAGE_WIND (IX, IY, WX, WY)
*
*   Return the window pixel coordinate WX,WY that maps to the top left corner of
*   the image pixel IX,IY.
}
procedure xform_image_wind (           {transform image to window coordinates}
  in      ix, iy: sys_int_machine_t;   {input image coordinates}
  out     wx, wy: sys_int_machine_t);  {output window coordinates}
  val_param;

begin
  wx := uli_x + (ix * zoom);
  wy := uli_y + (iy * zoom);
  end;
