{   Program IMAGE_OVL [<options>]
*
*   Apply overlay drawing from a .DISPL file to an image to make a composite
*   image.
}
program image_ovl;
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';
%include 'img.ins.pas';
%include 'vect.ins.pas';
%include 'rend.ins.pas';
%include 'displ.ins.pas';

const
  max_msg_args = 2;                    {max arguments we can pass to a message}

var
  fnam_in:                             {input image file name}
    %include '(cog)lib/string_treename.ins.pas';
  fnam_out:                            {output image file name}
    %include '(cog)lib/string_treename.ins.pas';
  fnam_displ:                          {overlay drawing file name}
    %include '(cog)lib/string_treename.ins.pas';
  imgin, imgout: img_conn_t;           {connections to input and output image files}
  displ: displ_t;                      {overlay drawing display list}
  iy: sys_int_machine_t;               {Y coordinate, scan line number}
  comm: string_list_t;                 {image comment lines}
  {
  *   RENDlib device state.
  }
  rend_dev: rend_dev_id_t;             {RENDlib ID for our graphics device}
  sizex, sizey: sys_int_machine_t;     {bitmap size in pixels}
  aspect: real;                        {width/height bitmap aspect ratio}
  bitmaph: rend_bitmap_handle_t;       {handle to RENDlib bitmap}
  bitmap_p: img_scan1_arg_p_t;         {pointer to bitmap pixels array}
  clip_handle: rend_clip_2dim_handle_t; {handle to 2DIM clip rectangle}
  {
  *   For command line handling and later general scratch.
  }
  opt:                                 {upcased command line option}
    %include '(cog)lib/string_treename.ins.pas';
  parm:                                {command line option parameter}
    %include '(cog)lib/string_treename.ins.pas';
  pick: sys_int_machine_t;             {number of token picked from list}
  msg_parm:                            {references arguments passed to a message}
    array[1..max_msg_args] of sys_parm_msg_t;
  stat: sys_err_t;                     {completion status code}

label
  next_opt, err_parm, parm_bad, done_opts;
{
********************************************************************************
*
*   Start of main routine.
}
begin
{
*   Initialize before reading the command line.
}
  string_cmline_init;                  {init for reading the command line}
{
*   Back here each new command line option.
}
next_opt:
  string_cmline_token (opt, stat);     {get next command line option name}
  if string_eos(stat) then goto done_opts; {exhausted command line ?}
  sys_error_abort (stat, 'string', 'cmline_opt_err', nil, 0);
  if (opt.len >= 1) and (opt.str[1] <> '-') then begin {implicit pathname token ?}
    string_copy (opt, fnam_in);        {save the image input file name}
    fnam_out.len := 0;                 {set output image to default}
    fnam_displ.len := 0;               {set overlay drawing file name to default}
    goto next_opt;
    end;
  string_upcase (opt);                 {make upper case for matching list}
  string_tkpick80 (opt,                {pick command line option name from list}
    '-IMG -IN -OUT -OVL',
    pick);                             {number of keyword picked from list}
  case pick of                         {do routine for specific option}
{
*   -IMG filename
}
1: begin
  string_cmline_token (fnam_in, stat); {get the input image file name}
  fnam_out.len := 0;                   {set output image to default}
  fnam_displ.len := 0;                 {set overlay drawing file name to default}
  end;
{
*   -IN filename
}
2: begin
  string_cmline_token (fnam_in, stat); {get the input image file name}
  end;
{
*   -OUT filename
}
3: begin
  string_cmline_token (fnam_out, stat); {get the output image file name}
  end;
{
*    -OVL filename
}
4: begin
  string_cmline_token (fnam_displ, stat); {get overlay drawing file name}
  end;
{
*   Unrecognized command line option.
}
otherwise
    string_cmline_opt_bad;             {unrecognized command line option}
    end;                               {end of command line option case statement}

err_parm:                              {jump here on error with parameter}
  string_cmline_parm_check (stat, opt); {check for bad command line option parameter}
  goto next_opt;                       {back for next command line option}

parm_bad:                              {jump here on got illegal parameter}
  string_cmline_reuse;                 {re-read last command line token next time}
  string_cmline_token (parm, stat);    {re-read the token for the bad parameter}
  sys_msg_parm_vstr (msg_parm[1], parm);
  sys_msg_parm_vstr (msg_parm[2], opt);
  sys_message_bomb ('string', 'cmline_parm_bad', msg_parm, 2);

done_opts:                             {done with all the command line options}
  if fnam_in.len <= 0 then begin
    sys_message_bomb ('string', 'cmline_input_fnam_missing', nil, 0);
    end;
{
*   Open the source image file.  This validates the source image and provides
*   basic dimension information.
}
  img_open_read_img (fnam_in, imgin, stat); {open input image for reading}
  sys_error_abort (stat, '', '', nil, 0);

  sizex := imgin.x_size;               {save image size and aspect ratio}
  sizey := imgin.y_size;
  aspect := imgin.aspect;

  string_list_copy (                   {save copy of image comment lines}
    imgin.comm,                        {the lines to copy}
    comm,                              {destination of the copy}
    util_top_mem_context);             {memory context for the new list}
{
*   Set up RENDlib now that the bitmap dimensions are known.
}
  rend_start;                          {init RENDlib}
  rend_open (                          {open our graphics device}
    string_v('*SW*'(0)),               {use software bitmap device}
    rend_dev,                          {returned RENDlib device ID}
    stat);                             {error status}
  sys_error_abort (stat, 'rend', 'rend_open', nil, 0);
  rend_set.enter_rend^;                {get into graphics mode}

  rend_set.alloc_bitmap_handle^ (      {create handle to bitmap of RGB values}
    rend_scope_dev_k,                  {memory belongs to the RENDlib device}
    bitmaph);                          {returned bitmap handle}

  rend_mem_alloc (                     {allocate memory for the image pixels}
    sizex * sizey * sizeof(img_pixel1_t), {amount of memory to allocate}
    rend_scope_dev_k,                  {allocate under the current device}
    false,                             {will not individually deallocate this mem}
    bitmap_p);                         {returned pointer to start of memory}

  rend_set.array_bitmap^ (             {use the pixels array as RENDlib bitmap}
    bitmaph,                           {handle to the bitmap}
    bitmap_p^,                         {the array to use as the bitmap}
    sizex, sizey,                      {pixel dimensions of the bitmap}
    sizeof(img_pixel1_t),              {adr offset for one pixel right}
    sizex * sizeof(img_pixel1_t));     {adr offset for one scan line down}

  rend_set.image_size^ (               {set image area size and aspect ratio}
    sizex, sizey, aspect);

  rend_set.iterp_on^ (rend_iterp_red_k, true); {turn on RGBA interpolants}
  rend_set.iterp_on^ (rend_iterp_grn_k, true);
  rend_set.iterp_on^ (rend_iterp_blu_k, true);
  rend_set.iterp_on^ (rend_iterp_alpha_k, true);

  rend_set.iterp_span_on^ (rend_iterp_red_k, true); {enable for SPAN primitive}
  rend_set.iterp_span_on^ (rend_iterp_grn_k, true);
  rend_set.iterp_span_on^ (rend_iterp_blu_k, true);
  rend_set.iterp_span_on^ (rend_iterp_alpha_k, true);

  rend_set.iterp_span_ofs^ (           {set offsets of components within pixel}
    rend_iterp_red_k, offset(img_pixel1_t.red));
  rend_set.iterp_span_ofs^ (
    rend_iterp_grn_k, offset(img_pixel1_t.grn));
  rend_set.iterp_span_ofs^ (
    rend_iterp_blu_k, offset(img_pixel1_t.blu));
  rend_set.iterp_span_ofs^ (
    rend_iterp_alpha_k, offset(img_pixel1_t.alpha));
  rend_set.span_config^ (sizeof(img_pixel1_t)); {offset for one pixel to the right}

  rend_set.iterp_bitmap^ (             {connect bitmap to red interpolant}
    rend_iterp_red_k,                  {interpolant ID to connect bitmap to}
    bitmaph,                           {handle to the bitmap}
    offset(img_pixel1_t.red));         {byte index into pixel for this interpolant}
  rend_set.iterp_bitmap^ (             {connect bitmap to green interpolant}
    rend_iterp_grn_k,
    bitmaph,
    offset(img_pixel1_t.grn));
  rend_set.iterp_bitmap^ (             {connect bitmap to blue interpolant}
    rend_iterp_blu_k,
    bitmaph,
    offset(img_pixel1_t.blu));
  rend_set.iterp_bitmap^ (             {connect bitmap to alpha interpolant}
    rend_iterp_alpha_k,
    bitmaph,
    offset(img_pixel1_t.alpha));

  rend_set.alpha_func^ (rend_afunc_over_k); {init alpha function}
  rend_set.alpha_on^ (true);           {enable alpha blending}
  rend_set.rgba^ (0.0, 0.0, 0.0, 1.0); {init color, opaque black}

  rend_get.clip_2dim_handle^ (clip_handle); {create handle to a 2DIM clip window}

  rend_set.clip_2dim^ (                {set clip window to whole device}
    clip_handle,                       {handle to the clip window}
    0, sizex,                          {X coordinate limits}
    0, sizey,                          {Y coordinate limits}
    true);                             {draw inside, clip outside}

  rend_set.min_bits_vis^ (24.0);       {set to full color resolution}
  rend_set.exit_rend^;                 {leave graphics mode}
{
*   Read the source image into the RENDlib bitmap, then close the source image
*   file.
}
  for iy := 0 to sizey-1 do begin      {down the scan lines}
    img_read_scan1 (                   {read this scan line}
      imgin,                           {connection to the image file}
      bitmap_p^[iy * sizex],           {scan line to read into}
      stat);
    sys_error_abort (stat, '', '', nil, 0);
    end;                               {back for next scan line}

  img_close (imgin, stat);             {close the input image file}
  sys_error_abort (stat, '', '', nil, 0);
{
*   Draw the overlay onto the bitmap.
}
  displ_list_new (util_top_mem_context, displ); {create overlay drawing display list}

  if fnam_displ.len <= 0 then begin    {use default display list file ?}
    string_pathname_split (imgin.tnam, parm, opt); {make directory in PARM}
    string_pathname_join (parm, imgin.gnam, fnam_displ); {make generic DISPL fnam}
    end;
  displ_file_read (fnam_displ, displ, stat); {read and save the display list}
  sys_error_abort (stat, '', '', nil, 0);

  displ_draw_list (displ);             {do all the overlay drawing}
{
*   Write the current bitmap contents to the image output file.
}
  if fnam_out.len <= 0 then begin      {no output image file name supplied ?}
    string_copy (imgin.tnam, fnam_out); {default to the input image file}
    end;
  img_open_write_img (                 {open the output image file}
    fnam_out,                          {file name}
    aspect,                            {width/height image aspect ratio}
    sizex, sizey,                      {image dimensions in pixels}
    '',                                {no specific file type, use file name}
    string_v('RED 8 GREEN 8 BLUE 8 ALPHA 8'), {format string for driver}
    comm,                              {list of comment lines}
    imgout,                            {returned connection to the image file}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  for iy := 0 to sizey-1 do begin      {down the scan lines}
    img_write_scan1 (                  {write this scan line to output file}
      imgout,                          {connection to the image file}
      bitmap_p^[iy * sizex],           {scan line to write from}
      stat);
    sys_error_abort (stat, '', '', nil, 0);
    end;                               {back for next scan line}

  img_close (imgout, stat);            {close the output image file}
  sys_error_abort (stat, '', '', nil, 0);
{
*   Clean up and leave.
}
  rend_end;                            {end use of RENDlib, close devs, dealloc resources}
  end.
