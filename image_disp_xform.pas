{   Coordinate transformations.
}
module idisp_xform;
define xform_make;
define xform_dpix_ipix;
define xform_ipix_dpix;
define xform_dpix_2d;
%include 'image_disp.ins.pas';
{
********************************************************************************
*
*   Subroutine XFORM_MAKE
*
*   Set up the transforms between the image and display coordinate spaces.  This
*   routine must be called whenever the display area changes size, or when an
*   image of different size is loaded into memory.
}
procedure xform_make;                  {create the coordinate transforms}
  val_param;

var
  r: real;                             {scratch floating point}
  x, y: real;                          {scratch coordinate}
  xf: vect_xf2d_t;                     {scratch 2D coordinate transform}

begin
  if not bitmap_alloc then return;     {drawing device is not known ?}
  if imgpix_p = nil then return;       {no image is loaded ?}
{
*   Compute the image to device transform.
}
  if img_aspect > dev_aspect
    then begin                         {image fills device horizontally}
      xpixid.xb.x := dev_dx / img_dx;  {horizontal scale}
      r := dev_aspect / img_aspect;    {fraction of device filled vertically}
      xpixid.yb.y :=                   {vertical scale}
        r * dev_dy / img_dy;
      xpixid.ofs.x := 0.0;             {left edges align}
      xpixid.ofs.y :=                  {dev Y of image top edge}
        dev_dy * (1.0 - r) * 0.5;
      end
    else begin                         {image fills device vertically}
      xpixid.yb.y := dev_dy / img_dy;  {vertical scale}
      r := img_aspect / dev_aspect;    {fraction of device filled horizontally}
      xpixid.xb.x :=                   {horizontal scale}
        r * dev_dx / img_dx;
      xpixid.ofs.y := 0.0;             {top edges align}
      xpixid.ofs.x :=                  {dev X of image left edge}
        dev_dx * (1.0 - r) * 0.5;
      end
    ;
  xpixid.xb.y := 0.0;                  {no rotation, cross terms zero}
  xpixid.yb.x := 0.0;
{
*   Use the image to device transform to make the device to image transform.
}
  xpixdi.xb.x := 1.0 / xpixid.xb.x;
  xpixdi.xb.y := 0.0;
  xpixdi.yb.x := 0.0;
  xpixdi.yb.y := 1.0 / xpixid.yb.y;

  xpixdi.ofs.x := -xpixid.ofs.x * xpixdi.xb.x;
  xpixdi.ofs.y := -xpixid.ofs.y * xpixdi.yb.y;
{
*   Set up the 2D space to image pixels transform in X2DIMG.  The +-1.0 square
*   is centered and maximized within the image.
}
  if img_aspect >= 1.0
    then begin                         {+-1 square fills image vertically}
      x2dimg.yb.y := -img_dy / 2.0;    {vertical scale}
      x2dimg.xb.x := img_dx / (2.0 * img_aspect); {horizontal scale}
      end
    else begin                         {+-1 square fills image horizontally}
      x2dimg.xb.x := img_dx / 2.0;     {horizontal scale}
      x2dimg.yb.y := -img_dy * img_aspect / 2.0; {vertical scale}
      end
    ;
  x2dimg.xb.y := 0.0;                  {no rotation, cross terms zero}
  x2dimg.yb.x := 0.0;

  x2dimg.ofs.x := img_dx / 2.0;        {origin is in middle of image}
  x2dimg.ofs.y := img_dy / 2.0;
{
*   Combine the 2D to image, and image to device transforms to make the 2D to
*   device transform and its inverse.
}
  vect_xf2d_mult (x2dimg, xpixid, x2ddev); {save 2D to device transform in X2DDEV}
  {
  *   Set the scale factors of the device pixels to 2D transform.  These are
  *   just the reciprocal of the forward scale factors since there is no
  *   rotation, and therefore no cross terms.
  }
  xdev2d.xb.x := 1.0 / x2ddev.xb.x;    {scale factors for dev pixels to 2D transform}
  xdev2d.xb.y := 0.0;
  xdev2d.yb.x := 0.0;
  xdev2d.yb.y := 1.0 / x2ddev.yb.y;
  {
  *   Fill in the offset vector of the device pixels to 2D transform.  The
  *   center of the device is always 0,0 in the 2D space.
  }
  x := dev_dx / 2.0;                   {make device pixels coor to transform}
  y := dev_dy / 2.0;

  xdev2d.ofs.x := -(x * xdev2d.xb.x + y * xdev2d.yb.x); {set ofs to negative result}
  xdev2d.ofs.y := -(x * xdev2d.xb.y + y * xdev2d.yb.y);
{
*   Set the RENDlib 2D transform.  This converts coordinates in the 2D space to
*   the canonical 2D space, where the +-1 square is centered and maximized in
*   the draw area.
}
  if dev_aspect >= 1.0
    then begin                         {+-1 square fills device vertically}
      if img_aspect >= dev_aspect
        then begin                     {image fills device horizontally}
          r := dev_aspect / img_aspect;
          end
        else begin                     {image fills device vertically}
          if img_aspect >= 1.0
            then r := 1.0
            else r := img_aspect;
          end
        ;
      end
    else begin                         {+-1 square fills device horizontally}
      if img_aspect >= dev_aspect
        then begin                     {image fills device horizontally}
          if img_aspect >= 1.0
            then r := 1.0 / img_aspect
            else r := 1.0;
          end
        else begin                     {image fills device vertically}
          r := img_aspect / dev_aspect;
          end
        ;
      end
    ;

  xf.xb.x := r;                        {fill in the complete transform}
  xf.xb.y := 0.0;
  xf.yb.x := 0.0;
  xf.yb.y := r;
  xf.ofs.x := 0.0;
  xf.ofs.y := 0.0;

  rend_set.enter_rend^;
  rend_set.xform_2d^ (xf.xb, xf.yb, xf.ofs); {set the 2D transform}
  rend_set.exit_rend^;
  end;
{
********************************************************************************
*
*   Subroutine XFORM_DPIX_IPIX (DEVX, DEVY, IMGX, IMGY)
*
*   Return the image pixel coordinate IMGX,IMGY that corresponds to the device
*   pixel coordinate DEVX,DEVY.
}
procedure xform_dpix_ipix (            {transform device to image pixel coordinates}
  in      devx, devy: real;            {input device pixel coordinate}
  out     imgx, imgy: real);           {output devide pixel coordinate}
  val_param;

begin
  imgx := devx * xpixdi.xb.x + devy * xpixdi.yb.x + xpixdi.ofs.x;
  imgy := devx * xpixdi.xb.y + devy * xpixdi.yb.y + xpixdi.ofs.y;
  end;
{
********************************************************************************
*
*   Subroutine XFORM_IPIX_DPIX (IMGX, IMGY, DEVX, DEVY)
*
*   Return the device pixel coordinate DEVX,DEVY that corresponds to the image
*   pixel coordinate IMGX,IMGY.
}
procedure xform_ipix_dpix (            {transform image to device pixel coordinates}
  in      imgx, imgy: real;            {input image pixel coordinate}
  out     devx, devy: real);           {output device pixel coordinate}
  val_param;

begin
  devx := imgx * xpixid.xb.x + imgy * xpixid.yb.x + xpixid.ofs.x;
  devy := imgx * xpixid.xb.y + imgy * xpixid.yb.y + xpixid.ofs.y;
  end;
{
********************************************************************************
*
*   Subroutine XFORM_DPIX_2D (DEVX, DEVY, XY2D)
*
*   Transform the center of the device pixel DEVX,DEVY to the 2D coordinate
*   space in D2X,D2Y)
}
procedure xform_dpix_2d (              {transform device pixel center to 2D space}
  in      devx, devy: sys_int_machine_t; {pixel to transform center point of}
  out     xy2d: vect_2d_t);            {returned 2D space coordinate}
  val_param;

begin
  vect_xf2d_xfpnt (                    {apply transform to a point}
    devx + 0.5, devy + 0.5,            {coordinate to transform}
    xdev2d,                            {the transform to apply}
    xy2d);                             {the result}
  end;
