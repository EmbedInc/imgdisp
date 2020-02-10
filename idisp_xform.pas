{   Coordinate transformations.
}
module idisp_xform;
define xform_make;
define xform_dpix_ipix;
define xform_ipix_dpix;
%include 'idisp.ins.pas';
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
*   Set up the 2D space to image transform in X2DIMG.  The +-1.0 square is
*   centered and maximized within the image.
}
  if img_aspect >= 1.0
    then begin                         {+-1 square fills image vertically}
      x2dimg.yb.y := img_dy / 2.0;     {vertical scale}
      x2dimg.xb.x := img_dx / (2.0 * img_aspect); {horizontal scale}
      end
    else begin                         {+-1 square fills image horizontally}
      x2dimg.xb.x := img_dx / 2.0;     {horizontal scale}
      x2dimg.yb.y := img_dy * img_aspect / 2.0; {vertical scale}
      end
    ;
  x2dimg.xb.y := 0.0;                  {no rotation, cross terms zero}
  x2dimg.yb.x := 0.0;

  x2dimg.ofs.x := img_dx / 2.0;        {origin is in middle of image}
  x2dimg.ofs.y := img_dy / 2.0;
{
*   Combine the 2D to image, and image to device transforms to make the 2D to
*   device transform.
}
  vect_xf2d_mult (x2dimg, xpixid, xf); {make 2D to device transform in XF}
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
