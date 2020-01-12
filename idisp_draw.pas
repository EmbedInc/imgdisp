{   Routines related to drawing.
}
module idisp_draw;
define draw_setup;
define draw_resize;
%include 'idisp.ins.pas';
{
********************************************************************************
*
*   Subroutine DRAW_SETUP
*
*   Do the one-time setup of RENDlib for our drawing.
}
procedure draw_setup;                  {one-time drawing setup, into graphics mode}
  val_param;

var
  use_sw: boolean;                     {TRUE if primitive uses SW bitmap}
  stat: sys_err_t;                     {completion status}

begin
  rend_start;                          {init RENDlib}
  rend_open (                          {open our graphics device}
    dev_name,                          {name of RENDlib device to use}
    rend_dev,                          {returned RENDlib device ID}
    stat);                             {error status}
  sys_error_abort (stat, 'rend', 'rend_open', nil, 0);
  rend_set.enter_rend^;                {get into graphics mode}

  rend_set.alloc_bitmap_handle^ (      {create handle to bitmap of RGB values}
    rend_scope_dev_k,                  {memory belongs to the RENDlib device}
    image_bitmap);                     {returned bitmap handle}
  bitmap_alloc := false;               {no bitmap pixels have been allocated}

  rend_get.clip_2dim_handle^ (clip_handle); {create handle to a 2DIM clip window}

  rend_set.iterp_on^ (rend_iterp_red_k, true); {turn on RGB interpolants}
  rend_set.iterp_on^ (rend_iterp_grn_k, true);
  rend_set.iterp_on^ (rend_iterp_blu_k, true);

  rend_set.iterp_span_on^ (rend_iterp_red_k, true); {enable for SPAN primitive}
  rend_set.iterp_span_on^ (rend_iterp_grn_k, true);
  rend_set.iterp_span_on^ (rend_iterp_blu_k, true);

  rend_set.iterp_span_ofs^ (           {set position in scan line pixels}
    rend_iterp_red_k, ord(img_col_red_k));
  rend_set.iterp_span_ofs^ (
    rend_iterp_grn_k, ord(img_col_grn_k));
  rend_set.iterp_span_ofs^ (
    rend_iterp_blu_k, ord(img_col_blu_k));
  rend_set.span_config^ (sizeof(img_pixel1_t)); {offset for one pixel to the right}

  xor_ok := true;                      {init to use XOR mode for dragging}

  drag_on;                             {set up state as if for dragging}
  rend_get.update_sw_prim^ (           {check for XOR vectors read SW bitmap}
    rend_prim.vect_2dimcl,             {call table entry for primitive}
    use_sw);                           {TRUE if XOR vectors use SW bitmap}
  drag_off;                            {restore state from dragging mode}

  if use_sw then begin                 {XOR vectors access SW bitmap ?}
    xor_ok := false;                   {init to not use XOR mode for dragging}
    drag_on;                           {set up state as if for dragging}
    rend_get.update_sw_prim^ (         {check for dragging vectors write SW bitmap}
      rend_prim.vect_2dimcl,           {call table entry for primitive}
      use_sw);                         {TRUE if would do SW emulation anyway}
    drag_off;                          {restore state from dragging mode}
    xor_ok := use_sw;                  {use XOR if alternative no better}
    end;
  end;
{
********************************************************************************
*
*   Subroutine DRAW_RESIZE
*
*   Update our internal state to the RENDlib device dimensions.
}
procedure draw_resize;                 {update to RENDlib drawing device size}
  val_param;

begin
  rend_set.enter_level^ (1);           {get into graphics mode}
  rend_get.image_size^ (               {find out what size window we have}
    image_width, image_height, aspect);

  if scan_dev_p <> nil then begin
    rend_mem_dealloc (scan_dev_p, rend_scope_dev_k); {deallocate scan line buffer}
    end;
  rend_mem_alloc (                     {allocate memory for RENDlib scan line}
    image_width * sizeof(img_pixel1_t), {amount of memory to allocate}
    rend_scope_dev_k,                  {memory belongs to the RENDlib device}
    true,                              {we will need to individually deallcate this}
    scan_dev_p);                       {returned pointer to the new memory}

  if bitmap_alloc then begin           {need to deallocate previous bitmap pixels ?}
    rend_set.dealloc_bitmap^ (image_bitmap); {deallocate old pixel memory}
    end;
  rend_set.alloc_bitmap^ (             {allocate the RGB pixels for this image}
    image_bitmap,                      {handle to this bitmap}
    image_width, image_height,         {size of image in pixels}
    3,                                 {number of bytes to allocate for each pixel}
    rend_scope_dev_k);                 {bitmap belongs to RENDlib device}
  bitmap_alloc := true;                {a bitmap is currently allocated}

  rend_set.iterp_bitmap^ (             {connect bitmap to red interpolant}
    rend_iterp_red_k,                  {interpolant ID to connect bitmap to}
    image_bitmap,                      {handle to the bitmap}
    0);                                {byte index into pixel for this interpolant}
  rend_set.iterp_bitmap^ (             {connect bitmap to green interpolant}
    rend_iterp_grn_k,
    image_bitmap,
    1);
  rend_set.iterp_bitmap^ (             {connect bitmap to blue interpolant}
    rend_iterp_blu_k,
    image_bitmap,
    2);

  rend_set.update_mode^ (rend_updmode_buffall_k); {may buffer pixel writes}

  rend_set.exit_rend^;

  if fit_on then begin                 {zoom image to fit draw area ?}
    zoom :=                            {largest zoom that still lets image fit}
      max(1, min(image_width div img.x_size, image_height div img.y_size));
    end;
  end;
