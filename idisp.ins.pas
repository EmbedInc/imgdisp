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
  max_msg_parms = 2;                   {max parameters we can pass to a message}
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

  inqrect_t = record                   {describes bounds of inquire rectangle}
    xmin, xmax: sys_int_machine_t;     {min/max X coordinates, inclusive}
    ymin, ymax: sys_int_machine_t;     {min/max Y coordinates, inclusive}
    end;

var (idisp)
  img_list: string_list_t;             {file names of images to display}
  img: img_conn_t;                     {handle to open image file}
  dev_name:                            {RENDlib device name}
    %include '(cog)lib/string_treename.ins.pas';
  rend_dev: rend_dev_id_t;             {RENDlib ID for our graphics device}
  image_width: sys_int_machine_t;      {horizontal size of RENDlib device}
  image_height: sys_int_machine_t;     {vertical size of RENDlib device}
  aspect: real;                        {aspect ratio of RENDlib device}
  wait: real;                          {seconds to wait in auto advance mode}
  clock_wait: sys_clock_t;             {WAIT value in sys clock format}
  clock_done: sys_clock_t;             {time when done waiting}
  image_bitmap: rend_bitmap_handle_t;  {handle to RENDlib bitmap}
  clip_handle: rend_clip_2dim_handle_t; {handle to 2DIM clip rectangle}
  anch_img: anch_t;                    {anchor point on raw image}
  anch_dev: anch_t;                    {anchor point on RENDlib device}
  uli_x, uli_y: sys_int_machine_t;     {dev pixel mapped to top left corner of image}
  zoom: sys_int_machine_t;             {integer zoom factor}
  x_zoom, y_zoom: sys_int_machine_t;   {current X and Y zoom phase}
  imgfile_info: file_info_t;           {file system info about image file}
  fit_on: boolean;                     {TRUE if -FIT command line option used}
  bitmap_alloc: boolean;               {TRUE if bitmap pixels already allocated}
  dith_on: boolean;                    {TRUE if dithering is ON}
  use_sw: boolean;                     {TRUE if primitive uses SW bitmap}
  xor_ok: boolean;                     {TRUE if use XOR mode when dragging}
  pending_resize: boolean;             {TRUE if window resized but not redrawn}
  pending_redraw: boolean;             {TRUE if window needs redrawing}
  auto_advance: boolean;               {automatically advance to next image}
  auto_loop: boolean;                  {loop back to first image after last}
  img_open: boolean;                   {TRUE if current image file open}
  backg_clear: boolean;                {TRUE if supposed to clear background}
  first_img: boolean;                  {TRUE on first image draw}
{
*   Routines.
}
procedure xform_wind_image (           {transform window to image coordinates}
  in      wx, wy: sys_int_machine_t;   {input window coordinates}
  out     ix, iy: sys_int_machine_t);  {output image coordinates}
  val_param; extern;

procedure xform_image_wind (           {transform image to window coordinates}
  in      ix, iy: sys_int_machine_t;   {input image coordinates}
  out     wx, wy: sys_int_machine_t);  {output window coordinates}
  val_param; extern;
