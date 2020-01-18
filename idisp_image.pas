{   Input images handling.
}
module idisp_image;
define image_pix_p;
define image_pos_next;
define image_pos_prev;
define image_load;
define image_unload;
define image_pix;
define image_sample;
%include 'idisp.ins.pas';
{
********************************************************************************
*
*   Function IMAGE_PIX_P (IX, IY)
*
*   Returns the pointer to the image pixel at coordinate IX,IY.  NIL is returned
*   when no image is loaded, or the coordinate is outside the image area.
}
function image_pix_p (                 {get pointer to image pixel}
  in      ix, iy: sys_int_machine_t)   {image pixel coordinate}
  :img_pixel1_p_t;                     {pointer to the pixel, NIL if not exist}
  val_param;

begin
  image_pix_p := nil;                  {init to addressed pixel does not exist}

  if                                   {this pixel does not exist ?}
      (imgpix_p = nil) or              {no image is loaded ?}
      (ix < 0) or (ix >= img_dx) or    {coordinate is outside image ?}
      (iy < 0) or (iy >= img_dy)
    then return;

  image_pix_p := addr(imgpix_p^[(iy * img_dx) + ix]);
  end;
{
********************************************************************************
*
*   Function IMAGE_POS_NEXT
*
*   Advance to the next image in the IMG_LIST list.  The function returns TRUE
*   if advanced to the next image.  It returns FALSE when there is no next image
*   to advance to.  In that case, the IMG_LIST position remains unchanged.
}
function image_pos_next                {position to next input image}
  :boolean;                            {TRUE positioned, FALSE no image to go to}
  val_param;

begin
  image_pos_next := true;              {init to did advance to next image}

  if img_list.curr = img_list.n then begin {currently at last image in list ?}
    if list_loop then begin            {list is circular ?}
      string_list_pos_abs (img_list, 1); {go to first list entry}
      return;
      end;
    image_pos_next := false;           {no image to advance to}
    return;
    end;

  string_list_pos_rel (img_list, 1);   {advance to next image in the list}
  end;
{
********************************************************************************
*
*   Function IMAGE_POS_PREV
*
*   Position the images list IMG_LIST to the previous entry.  The function
*   returns TRUE is the list position was changed, and FALSE if there is no
*   previous image to position to.  In that case, the position is not changed.
}
function image_pos_prev                {position to previous input image}
  :boolean;                            {TRUE positioned, FALSE no image to go to}
  val_param;

begin
  image_pos_prev := true;              {init to did position to next image}

  if img_list.curr = 1 then begin      {currently at first list entry ?}
    if list_loop then begin            {list is circular ?}
      string_list_pos_last (img_list); {wrap back to last list entry}
      return;
      end;
    image_pos_prev := false;           {no image to position to}
    return;
    end;

  string_list_pos_rel (img_list, -1);  {position to previous image in the list}
  end;
{
********************************************************************************
*
*   Subroutine IMAGE_LOAD (STAT)
*
*   Make sure that information about the current image is loaded into memory.
*   The current image is the one indicated by the current IMG_LIST entry.
}
procedure image_load (                 {load the current image into memory}
  out     stat: sys_err_t);
  val_param;

var
  img: img_conn_t;                     {connection to the image file}
  scan_p: img_scan1_arg_p_t;           {pointer to start of current scan line}
  y: sys_int_machine_t;                {image Y coordinate (scan line index)}
  pix_p: img_pixel1_p_t;               {pointer to addressed pixel}
  stat2: sys_err_t;                    {to avoid corrupting STAT}

label
  abort1, abort2;

begin
  sys_error_none (stat);               {init to no error encountered}

  if imgpix_p <> nil then begin        {some image already loaded ?}
    if imgpos = img_list.curr then return; {the desired image is already loaded ?}
    image_unload (stat);               {release resources for currently loaded image}
    if sys_error(stat) then return;
    end;

  img_open_read_img (img_list.str_p^, img, stat); {try to open new image file}
  if sys_error(stat) then return;      {error opening image file ?}
  imgpos := img_list.curr;             {save list entry number of open image}

  img_dx := img.x_size;                {save information about this image}
  img_dy := img.y_size;
  img_aspect := img.aspect;
{
*   Read the image pixels into our array, then close the image file.
}
  rend_mem_alloc (                     {alloc memory for the image pixels}
    img_dx * img_dy * sizeof(img_pixel1_t), {amount of memory to allocate}
    rend_scope_dev_k,                  {associate the memory with the RENDlib dev}
    true,                              {will need to individually dealloc this mem}
    imgpix_p);                         {returned pointer to the new memory}

  scan_p := imgpix_p;                  {init pointer to top scan line}
  for y := 0 to img_dy-1 do begin      {loop over the scan lines in the image}
    pix_p := image_pix_p (0, y);       {get pointer to first pixel of scan line}
    img_read_scan1 (                   {read this scan line into pixels array}
      img,                             {connection to the image file}
      pix_p^,                          {scan line to read into}
      stat);
    if sys_error(stat) then goto abort2;
    end;

  img_close (img, stat);               {close connection to the image file}
  if sys_error(stat) then goto abort2;
{
*   Update our state to the new image dimensions.
}
  xform_make;                          {create coordinate transforms}
  return;                              {normal return point}
{
*   Error exits.  STAT is already set to indicate the error.
}
abort2:                                {error with pixels array allocated}
  rend_mem_dealloc (imgpix_p, rend_scope_dev_k); {deallocate pixels array}

abort1:                                {the image file is open}
  img_close (img, stat2);              {close the image file}
  end;
{
********************************************************************************
*
*   Subroutine IMAGE_UNLOAD (STAT)
*
*   Make sure no input image is open.
}
procedure image_unload (               {deallocate state for current image}
  out     stat: sys_err_t);
  val_param;

begin
  sys_error_none (stat);               {init to no error encountered}
  if imgpix_p = nil then return;       {no image loaded ?}

  rend_mem_dealloc (imgpix_p, rend_scope_dev_k); {deallocate pixels array}
  end;
{
********************************************************************************
*
*   Function IMAGE_PIX (IX, IY, PIX)
*
*   Get the pixel value at image coordinates IX,IY.
*
*   When IX,IY is a valid pixel coordinate within the image, then PIX is set to
*   the pixel value and the function returns TRUE.
*
*   When IX,IY is not a valid pixel coordinate of the current image, then PIX is
*   set to totally transparent black, and the function returns FALSE.
}
function image_pix (                   {get image pixel}
  in      ix, iy: sys_int_machine_t;   {image pixel coordinate}
  out     pix: img_pixel1_t)           {pixel value}
  :boolean;                            {coordinate was within image}
  val_param;

var
  pix_p: img_pixel1_p_t;               {pointer to the addressed pixel}


begin
  pix_p := image_pix_p (ix, iy);       {get pointer to the addressed pixel}

  if pix_p = nil then begin            {the pixel does not exist ?}
    pix.red := 0;
    pix.grn := 0;
    pix.blu := 0;
    pix.alpha := 0;
    image_pix := false;
    return;
    end;

  image_pix := true;                   {indicate coordinate is within image}
  pix := pix_p^;                       {return the pixel value}
  end;
{
********************************************************************************
*
*   Function IMAGE_SAMPLE (X, Y, VAL)
*
*   Return the point-sample of the currently loaded image at X,Y.  X and Y are
*   in units of pixels.  The origin is the top left corner of the top left pixel
*   in the image.  X extends to the right and Y extends down.
*
*   For areas outside the image, the function returns FALSE and VAL is set to
*   fully transparent black.  Otherwise, the function returns TRUE and VAL is
*   set to the value of the pixel that the X,Y coordinate falls within.
}
function image_sample (                {sample image at a point}
  in      x, y: real;                  {coor to sample at, units of pixels}
  out     val: img_pixel1_t)           {returned image value at X,Y}
  :boolean;                            {within image, returning with actual value}
  val_param;

begin
  if (x < 0.0) or (y < 0.0) then begin {definitely outside the image ?}
    image_sample := false;
    val.red := 0;
    val.grn := 0;
    val.blu := 0;
    val.alpha := 0;
    return;
    end;

  image_sample := image_pix (trunc(x), trunc(y), val);
  end;
