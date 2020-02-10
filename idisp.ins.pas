{   Private include file for the IMAGE_DISP program.
}
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';
%include 'img.ins.pas';
%include 'vect.ins.pas';
%include 'rend.ins.pas';
%include 'displ.ins.pas';

const
  default_rendlib_dev = 'IMAGE_DISP';  {default RENDlib device name}
  zoom_factor = 1.50;                  {relative incremental zoom factor}
{
*   Our internal IDs for interactive keys the user can hit.
}
  key_unused_k = 0;                    {value for when internal key ID not used}
  key_next_k = 1;                      {advance to next image in list}
  key_prev_k = 2;                      {advance to previous image in list}
  key_point_k = 3;                     {main pointer key}
  key_clear_k = 4;                     {clear drawing}

type
  anch_t = record                      {info about an anchor point}
    x, y: real;                        {0.0 to 1.0 relative anchor value}
    end;

var (idisp)
  {
  *   User parameters.
  }
  img_list: string_list_t;             {file names of images to display}
  wait: real;                          {seconds to wait in auto advance mode}
  dev_name:                            {RENDlib device name}
    %include '(cog)lib/string_treename.ins.pas';
  auto_advance: boolean;               {automatically advance to next image}
  list_loop: boolean;                  {loop back to first image after last}
  {
  *   RENDlib device state.
  }
  rend_dev: rend_dev_id_t;             {RENDlib ID for our graphics device}
  image_bitmap: rend_bitmap_handle_t;  {handle to RENDlib bitmap}
  clip_handle: rend_clip_2dim_handle_t; {handle to 2DIM clip rectangle}
  dev_dx, dev_dy: sys_int_machine_t;   {size of drawing device, pixels}
  dev_aspect: real;                    {aspect ratio of drawing device}
  scan_dev_p: img_scan1_arg_p_t;       {pointer to scan line for RENDlib device}
  bitmap_alloc: boolean;               {TRUE if bitmap pixels already allocated}
  {
  *   Current source image information.
  }
  imgpos: sys_int_machine_t;           {IMG_LIST entry number of open image}
  img_dx, img_dy: sys_int_machine_t;   {image dimensions, pixels}
  img_aspect: real;                    {aspect ratio of the whole image}
  imgpix_p: img_scan1_arg_p_t;         {pointer to source image pixels array}
  {
  *   Other state.
  }
  clock_wait: sys_clock_t;             {-WAIT value in sys clock format}
  xpixid: vect_xf2d_t;                 {image to device pixel coor transform}
  xpixdi: vect_xf2d_t;                 {device to image pixel coor transform}
  x2dimg: vect_xf2d_t;                 {2D to image transform}
  x2ddev: vect_xf2d_t;                 {2D to device pixels transform}
  xdev2d: vect_xf2d_t;                 {device pixels to 2D transform}
  ovl_list: displ_t;                   {display list to draw over picture}
{
*   Routines.
}
procedure draw_image (                 {draw rectangle onto drawing device}
  in      stx, sty: sys_int_machine_t; {top left pixel to draw, drawing device coor}
  in      szx, szy: sys_int_machine_t); {pixel width and height of rectangle}
  val_param; extern;

procedure draw_resize;                 {update to RENDlib drawing device size}
  val_param; extern;

procedure draw_setup;                  {one-time drawing setup, into graphics mode}
  val_param; extern;

procedure event_pointer_dblclick (     {process main pointer key double click}
  in      evx, evy: sys_int_machine_t); {draw device coor of event}
  val_param; extern;

procedure event_pointer_down (         {handle main pointer key pressed event}
  in      evx, evy: sys_int_machine_t; {draw device coor of event}
  in      modk: rend_key_mod_t);       {modifiers active at time of event}
  val_param; extern;

procedure event_pointer_move (         {handle pointer motion}
  in      evx, evy: sys_int_machine_t); {new pointer coordinate}
  val_param; extern;

procedure event_pointer_up (           {handle main pointer key released event}
  in      evx, evy: sys_int_machine_t; {draw device coor of event}
  in      modk: rend_key_mod_t);       {modifiers active at time of event}
  val_param; extern;

procedure event_setup;                 {set up RENDlib events for our use}
  val_param; extern;

procedure image_load (                 {load the current image into memory}
  out     stat: sys_err_t);
  val_param; extern;

function image_pix (                   {get image pixel}
  in      ix, iy: sys_int_machine_t;   {image pixel coordinate}
  out     pix: img_pixel1_t)           {pixel value}
  :boolean;                            {coordinate was within image}
  val_param; extern;

function image_pix_p (                 {get pointer to image pixel}
  in      ix, iy: sys_int_machine_t)   {image pixel coordinate}
  :img_pixel1_p_t;                     {pointer to the pixel, NIL if not exist}
  val_param; extern;

function image_pos_next                {position to next input image}
  :boolean;                            {TRUE positioned, FALSE no image to go to}
  val_param; extern;

function image_pos_prev                {position to previous input image}
  :boolean;                            {TRUE positioned, FALSE no image to go to}
  val_param; extern;

function image_sample (                {sample image at a point}
  in      x, y: real;                  {coor to sample at, units of pixels}
  out     val: img_pixel1_t)           {returned image value at X,Y}
  :boolean;                            {within image, returning with actual value}
  val_param; extern;

procedure image_unload (               {deallocate state for current image}
  out     stat: sys_err_t);
  val_param; extern;

procedure ovl_close;                   {close and deallocate curr image overlay}
  val_param; extern;

procedure ovl_draw;                    {draw all the overlay graphics}
  val_param; extern;

procedure ovl_init;                    {one-time initialization of OVL_INT module}
  val_param; extern;

procedure ovl_open;                    {init overlay for current image}
  val_param; extern;

procedure ovl_vects_add (              {add vector to vectors chain}
  in      x, y: real);                 {new vectors chain end coordinate}
  val_param; extern;

procedure ovl_vects_cancel;            {cancel the vectors chain currently building}
  val_param; extern;

procedure ovl_vects_end;               {end current vectors chain}
  val_param; extern;

procedure ovl_vects_start (            {start new chain of vectors}
  in      x, y: real);                 {starting coordinate}
  val_param; extern;

procedure xform_dpix_2d (              {transform device pixel center to 2D space}
  in      devx, devy: sys_int_machine_t; {pixel to transform center point of}
  out     xy2d: vect_2d_t);            {returned 2D space coordinate}
  val_param; extern;

procedure xform_dpix_ipix (            {transform device to image pixel coordinates}
  in      devx, devy: real;            {input device pixel coordinate}
  out     imgx, imgy: real);           {output image pixel coordinate}
  val_param; extern;

procedure xform_ipix_dpix (            {transform image to device pixel coordinates}
  in      imgx, imgy: real;            {input image pixel coordinate}
  out     devx, devy: real);           {output device pixel coordinate}
  val_param; extern;

procedure xform_make;                  {create the coordinate transforms}
  val_param; extern;
