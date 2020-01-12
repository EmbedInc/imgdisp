{   Private include file for the IMAGE_DISP program.
}
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';
%include 'img.ins.pas';
%include 'vect.ins.pas';
%include 'rend.ins.pas';

const
  default_rendlib_dev = 'IMAGE_DISP';  {default RENDlib device name}
  zoom_factor = 1.50;                  {relative incremental zoom factor}
{
*   Our internal IDs for interactive keys the user can hit.
}
  key_pan_k = 1;                       {translate image in X,Y on screen}
  key_inquire_k = 2;                   {inquire value of image region}
  key_zoom_in_k = 3;                   {increase image magnification}
  key_zoom_out_k = 4;                  {decrease image magnification}
  key_zoom_k = 5;                      {zoom in/out depending on SHIFT}
  key_next_k = 6;                      {advance to next image in list}
  key_prev_k = 7;                      {advance to previous image in list}

type
  anch_t = record                      {info about an anchor point}
    x, y: real;                        {0.0 to 1.0 relative anchor value}
    end;

var (idisp)
  {
  *   User parameters.
  }
  img_list: string_list_t;             {file names of images to display}
  anch_img: anch_t;                    {anchor point on raw image}
  anch_dev: anch_t;                    {anchor point on RENDlib device}
  zoom: sys_int_machine_t;             {integer zoom factor}
  wait: real;                          {seconds to wait in auto advance mode}
  dev_name:                            {RENDlib device name}
    %include '(cog)lib/string_treename.ins.pas';
  fit_on: boolean;                     {use max zoom where image still fits}
  auto_advance: boolean;               {automatically advance to next image}
  auto_loop: boolean;                  {loop back to first image after last}
  backg_clear: boolean;                {TRUE if supposed to clear background}
  {
  *   Internal current state.
  }
  rend_dev: rend_dev_id_t;             {RENDlib ID for our graphics device}
  image_bitmap: rend_bitmap_handle_t;  {handle to RENDlib bitmap}
  clip_handle: rend_clip_2dim_handle_t; {handle to 2DIM clip rectangle}
  scan_img_p: img_scan1_arg_p_t;       {pointer to scan line from image file}
  image_width: sys_int_machine_t;      {horizontal size of RENDlib device}
  image_height: sys_int_machine_t;     {vertical size of RENDlib device}
  aspect: real;                        {aspect ratio of RENDlib device}
  uli_x, uli_y: sys_int_machine_t;     {dev pixel mapped to top left corner of image}
  x_zoom, y_zoom: sys_int_machine_t;   {current X and Y zoom phase}
  img: img_conn_t;                     {handle to open image file}
  imgfile_info: file_info_t;           {file system info about image file}
  scan_dev_p: img_scan1_arg_p_t;       {pointer to scan line for RENDlib device}
  bitmap_alloc: boolean;               {TRUE if bitmap pixels already allocated}
  xor_ok: boolean;                     {TRUE if use XOR mode when dragging}
  img_open: boolean;                   {TRUE if current image file open}
  first_img: boolean;                  {TRUE on first image draw}
{
*   Routines.
}
procedure drag_draw;                   {draw dragged object}
  val_param; extern;

procedure drag_off;                    {end drag operation}
  val_param; extern;

procedure drag_on;                     {start drag operation}
  val_param; extern;

procedure drag_undraw;                 {undraw dragged object}
  val_param; extern;

procedure draw_resize;                 {update to RENDlib drawing device size}
  val_param; extern;

procedure draw_setup;                  {one-time drawing setup, into graphics mode}
  val_param; extern;

procedure event_inquire (              {handle ENQUIRE key event}
  in      evx, evy: sys_int_machine_t); {window coordinate of the enquire event}
  val_param; extern;

function event_pan (                   {handle user PAN event}
  in      evx, evy: sys_int_machine_t) {window coordinate of the PAN start}
  :boolean;                            {TRUE if redraw required}
  val_param; extern;

procedure event_setup;                 {set up RENDlib events for our use}
  val_param; extern;

procedure image_close (                {make sure no input image is open}
  out     stat: sys_err_t);
  val_param; extern;

procedure image_open (                 {make sure current image is open}
  out     stat: sys_err_t);
  val_param; extern;

function image_next                    {advance to next input image}
  :boolean;                            {TRUE advanced, FALSE no image to advance to}
  val_param; extern;

procedure xform_wind_image (           {transform window to image coordinates}
  in      wx, wy: sys_int_machine_t;   {input window coordinates}
  out     ix, iy: sys_int_machine_t);  {output image coordinates}
  val_param; extern;

procedure xform_image_wind (           {transform image to window coordinates}
  in      ix, iy: sys_int_machine_t;   {input image coordinates}
  out     wx, wy: sys_int_machine_t);  {output window coordinates}
  val_param; extern;
