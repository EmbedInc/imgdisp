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
