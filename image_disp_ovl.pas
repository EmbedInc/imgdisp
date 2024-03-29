{   Routines for managing the overlay graphics.
}
module idisp_ovl;
define ovl_init;
define ovl_open;
define ovl_close;
define ovl_clear;
define ovl_draw;
define ovl_vects_start;
define ovl_vects_cancel;
define ovl_vects_add;
define ovl_vects_end;
%include 'image_disp.ins.pas';

const
  def_red = 1.0;                       {default color}
  def_grn = 0.4;
  def_blu = 0.2;
  def_wid = (2.0 / 1080.0) * 3.0;      {default vector width, 3 pixels at 1080 dim}

var
  def_color: displ_color_t;            {global default color}
  def_vparm: displ_vparm_t;            {global default vector drawing parameters}
  def_tparm: displ_tparm_t;            {global default text drawing parameters}
  ledit: displ_edit_t;                 {state for editing the display list}
  vedit: displ_edvect_t;               {state for editing the curr vector chain}
{
********************************************************************************
*
*   Subroutine OVL_INIT
*
*   One-time call to initialize the state managed by this module.  RENDlib must
*   already be initialized.
}
procedure ovl_init;                    {one-time initialization of OVL_INT module}
  val_param;

begin
  rend_set.enter_rend^;                {into graphic mode}

  def_color.red := def_red;            {set global default color}
  def_color.grn := def_grn;
  def_color.blu := def_blu;
  def_color.opac := 1.0;
  rend_set.rgba^ (                     {set to the default color}
    def_color.red, def_color.grn, def_color.blu, def_color.opac);

  rend_get.vect_parms^ (def_vparm.vparm); {make sure all vect parm fields set}
  def_vparm.vparm.width := def_wid;
  def_vparm.vparm.poly_level := rend_space_2d_k; {vectors to polygons in 2D space}
  def_vparm.vparm.start_style.style := rend_end_style_circ_k;
  def_vparm.vparm.start_style.nsides := 4;
  def_vparm.vparm.end_style.style := rend_end_style_circ_k;
  def_vparm.vparm.end_style.nsides := 4;
  def_vparm.vparm.subpixel := true;
  rend_set.vect_parms^ (def_vparm.vparm); {set to the default vector drawing parameters}

  rend_get.text_parms^ (def_tparm.tparm); {make sure all text parm fields set}

  rend_set.exit_rend^;                 {pop back out of graphics mode}
  end;
{
********************************************************************************
*
*   Local subroutine OVL_LIST_CREATE
*
*   Create and initialize the overlay drawing display list.
}
procedure ovl_list_create;
  val_param; internal;

begin
  displ_list_new (                     {create the display list}
    util_top_mem_context, ovl_list);
  {
  *   Set the global default drawing parameters for the overlay.
  }
  ovl_list.rend.color_p := addr(def_color);
  ovl_list.rend.vect_parm_p := addr(def_vparm);
  ovl_list.rend.text_parm_p := addr(def_tparm);

  displ_edit_init (ledit, ovl_list);   {init state for editing the list}
  end;
{
********************************************************************************
*
*   Subroutine OVL_OPEN
*
*   Initialize the overlay data for the current image.
}
procedure ovl_open;                    {init overlay for current image}
  val_param;

var
  fnam: string_treename_t;             {overlay display list file name}
  stat: sys_err_t;

begin
  fnam.max := size_char(fnam.str);     {init local var strings}

  ovl_list_create;                     {create and init the display list}
  {
  *   Read the display list file, if one exists for this image.
  }
  string_pathname_join (img_dir, img_gnam, fnam); {make generic image treename}
  displ_file_read (                    {try to read display list file}
    fnam,                              {file name, ".displ" suffix implied}
    ovl_list,                          {display list to add file data to}
    stat);
  discard( file_not_found(stat) );     {no display list file is not an error}
  sys_error_abort (stat, '', '', nil, 0); {complain and abort on hard error}
  end;
{
********************************************************************************
*
*   Subroutine OVL_CLOSE
*
*   Close the overlay data for the current image, deallocate resources.
}
procedure ovl_close;                   {close and deallocate curr image overlay}
  val_param;

var
  fnam: string_treename_t;             {overlay display list file name}
  stat: sys_err_t;

begin
  fnam.max := size_char(fnam.str);     {init local var strings}

  string_pathname_join (img_dir, img_gnam, fnam); {make generic image treename}
  string_appends (fnam, '.displ'(0));  {make full display list file name}

  if displ_list_draws(ovl_list)
    then begin                         {this list causes drawing, save it}
      displ_file_write (fnam, ovl_list, stat); {save overlay display list in file}
      sys_error_abort (stat, '', '', nil, 0);
      end
    else begin                         {there is no overlay drawing}
      if file_exists (fnam) then begin {a display list file exists ?}
        file_delete_name (fnam, stat); {delete it}
        sys_error_abort (stat, '', '', nil, 0);
        end;
      end
    ;

  displ_list_del (ovl_list);
  end;
{
********************************************************************************
*
*   Subroutine OVL_CLEAR
*
*   Delete all the overlay drawing.
}
procedure ovl_clear;                   {delete all overlay drawing}
  val_param;

begin
  displ_list_del (ovl_list);           {delete the display list, deallocate resources}
  ovl_list_create;                     {create a new empty display list}
  end;
{
********************************************************************************
*
*   Subroutine OVL_DRAW
*
*   Draw all the overlay graphics.  RENDlib is assumed to be in graphics mode.
}
procedure ovl_draw;                    {draw all the overlay graphics}
  val_param;

begin
  displ_draw_list (ovl_list);          {draw the whole display list contents}
  end;
{
********************************************************************************
*
*   Subroutine OVL_VECTS_START (X, Y)
*
*   Start a new vectors chain.  X,Y is the starting coordinate.
}
procedure ovl_vects_start (            {start new chain of vectors}
  in      x, y: real);                 {starting coordinate}
  val_param;

begin
  displ_item_new (ledit);              {create a new blank display list entry}
  displ_item_vect (ledit);             {make the new item a chain of vectors}
  displ_edvect_init (vedit, ledit.item_p^); {init edit position into vectors chain}
  displ_edvect_add (vedit, x, y);      {create the vectors chain starting point}
  end;
{
********************************************************************************
*
*   Subroutine OVL_VECTS_CANCEL
*
*   Cancel the current vectors chain display list item.  The vectors chain will
*   be deleted.
}
procedure ovl_vects_cancel;            {cancel the vectors chain currently building}
  val_param;

begin
  displ_edit_del (ledit, false);       {delete the current display list item}
  end;
{
********************************************************************************
*
*   Subroutine OVL_VECTS_ADD (X, Y)
*
*   Add another vector to the current vectors chain.  The new vector will go
*   from the current last point to X,Y, which will then become the vectors chain
*   new end point.
}
procedure ovl_vects_add (              {add vector to vectors chain}
  in      x, y: real);                 {new vectors chain end coordinate}
  val_param;

begin
  displ_edvect_add (vedit, x, y);
  end;
{
********************************************************************************
*
*   Subroutine OVL_VECTS_END
*
*   End the current vectors chain being built.
}
procedure ovl_vects_end;               {end current vectors chain}
  val_param;

begin
  end;
